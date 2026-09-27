import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../repositories/firestore_workout_repository.dart';
import '../repositories/sqlite_workout_repository.dart';
import '../data/database_helper.dart';
import 'deleted_sessions_store.dart';
import 'session_manager.dart';
import 'settings_sync_service.dart';

/// 端末（SQLite）とクラウド（Firestore）の記録を同期するサービス。
///
/// **全体同期**（ログイン時・起動時）: 双方向にマージする。
/// - 端末にしかない記録 → クラウドへアップロード
/// - クラウドにしかない記録 → 端末へダウンロード
/// - 両方にある記録（同じ ID） → 最終更新日時が新しい方を両方に反映
///   （更新日時が無い古いデータ同士は、端末側を優先）
///
/// **差分同期**（アプリが前面に戻ったとき）: 前回の同期以降にクラウドで変わった記録と
/// 削除の印だけを取り込む（読み取り件数を抑えるため）。端末での変更は保存時に
/// クラウドへ書き込み済み。書き込みに失敗した分は、次の全体同期で送られる。
///
/// **削除の同期**: 削除した記録は「削除の印（ID と削除時刻）」を端末とクラウドに残す。
/// 印より前に更新された記録は、どちらにあっても削除する。印より後に編集された記録は
/// 「削除後に編集された」ものとして残し、印を取り消す。
///
/// あわせて、設定（体重・ルーチン・お気に入りなど）も [SettingsSyncService] で同期する。
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// 前面復帰時の同期を、この間隔より短い頻度では行わない。
  static const resumeInterval = Duration(seconds: 30);

  bool _running = false;
  DateTime? _lastRun;

  String _markKey(String uid) => 'sync_cloud_mark_$uid';

  /// ログイン時・起動時の全体同期。
  Future<void> syncOnLogin(String uid) => _run(uid, full: true);

  /// 前面に戻ったときの差分同期（短い間隔での連続実行はしない）。
  Future<void> syncOnResume(String uid) async {
    final last = _lastRun;
    if (last != null && DateTime.now().difference(last) < resumeInterval) {
      return;
    }
    await _run(uid, full: false);
  }

  Future<void> _run(String uid, {required bool full}) async {
    if (_running) return;
    _running = true;
    _lastRun = DateTime.now();
    try {
      debugPrint('[Sync] start (${full ? 'full' : 'incremental'}) uid=$uid');
      final prefs = await SharedPreferences.getInstance();
      final mark = prefs.getString(_markKey(uid));
      final result = (full || mark == null)
          ? await _fullSync(uid)
          : await _pull(uid, mark);
      final newMark = result.newMark;
      if (newMark != null) {
        // 端末ごとの時計のずれに備え、少し前から取り直すよう5分戻して保存する
        final t = DateTime.tryParse(newMark);
        await prefs.setString(
          _markKey(uid),
          t == null
              ? newMark
              : t.subtract(const Duration(minutes: 5)).toIso8601String(),
        );
      }
      SessionManager.instance.applyExternalChanges(
        updated: result.updated,
        deleted: result.deleted,
      );
      debugPrint('[Sync] done: ${result.updated.length} updated, '
          '${result.deleted.length} deleted locally');
    } catch (e) {
      debugPrint('[Sync] sync failed: $e');
    } finally {
      _running = false;
    }
    try {
      await SettingsSyncService.instance.sync(uid);
    } catch (e) {
      debugPrint('[Sync] settings sync failed: $e');
    }
  }

  // ── 全体同期 ─────────────────────────────────────────────────

  Future<_SyncResult> _fullSync(String uid) async {
    final local = SqliteWorkoutRepository(DatabaseHelper.instance);
    final cloud = FirestoreWorkoutRepository(uid);
    final store = DeletedSessionsStore.instance;

    final localById = {for (final s in await local.getAllSessions()) s.id: s};
    final cloudById = {for (final s in await cloud.getAllSessions()) s.id: s};
    final localTombs = await store.load();
    final cloudTombs = await cloud.getTombstones() ?? {};

    final updated = <WorkoutSession>[];
    final deleted = <String>{};

    // 1. 削除の印を反映
    final tombs = mergeTombstones(localTombs, cloudTombs);
    for (final e in tombs.entries) {
      final id = e.key, at = e.value;
      final l = localById[id], c = cloudById[id];
      if (isEditedAfterDeletion(l, at) || isEditedAfterDeletion(c, at)) {
        // 削除後に編集された記録は残し、削除の印を取り消す
        await store.remove(id);
        if (cloudTombs.containsKey(id)) await cloud.removeTombstone(id);
        continue;
      }
      if (l != null) {
        await local.deleteSession(id);
        localById.remove(id);
        deleted.add(id);
      }
      if (c != null) {
        await cloud.removeSessionDoc(id);
        cloudById.remove(id);
      }
      if (localTombs[id] != at) await store.put(id, at);
      if (cloudTombs[id] != at) await cloud.putTombstone(id, at);
    }

    // 2. 残った記録を双方向にマージ
    for (final l in localById.values) {
      final c = cloudById[l.id];
      if (c == null) {
        await cloud.upsertSession(l);
      } else if (isNewer(c, than: l)) {
        await local.upsertSession(c);
        updated.add(c);
      } else if (isNewer(l, than: c) ||
          (l.updatedAt == null && c.updatedAt == null)) {
        await cloud.upsertSession(l);
      }
    }
    for (final c in cloudById.values) {
      if (!localById.containsKey(c.id)) {
        await local.upsertSession(c);
        updated.add(c);
      }
    }

    final newMark = maxMark([
      for (final s in cloudById.values) s.updatedAt,
      for (final s in localById.values) s.updatedAt,
      ...tombs.values,
    ]);
    return _SyncResult(updated, deleted, newMark);
  }

  // ── 差分同期 ─────────────────────────────────────────────────

  Future<_SyncResult> _pull(String uid, String mark) async {
    final local = SqliteWorkoutRepository(DatabaseHelper.instance);
    final cloud = FirestoreWorkoutRepository(uid);
    final store = DeletedSessionsStore.instance;

    final changed = await cloud.getSessionsUpdatedAfter(mark);
    final newTombs = await cloud.getTombstones(after: mark);
    // 取得に失敗したときは何もしない（次回の同期で取り直す）
    if (changed == null || newTombs == null) return _SyncResult([], {}, null);
    if (changed.isEmpty && newTombs.isEmpty) return _SyncResult([], {}, null);

    final localById = {for (final s in await local.getAllSessions()) s.id: s};
    final localTombs = await store.load();
    final updated = <WorkoutSession>[];
    final deleted = <String>{};

    for (final c in changed) {
      final t = localTombs[c.id];
      if (t != null && !isEditedAfterDeletion(c, t)) continue; // 端末で削除済み
      final l = localById[c.id];
      if (l == null || isNewer(c, than: l)) {
        await local.upsertSession(c);
        updated.add(c);
      }
    }
    for (final e in newTombs.entries) {
      final l = localById[e.key];
      if (l != null && !isEditedAfterDeletion(l, e.value)) {
        await local.deleteSession(e.key);
        deleted.add(e.key);
        updated.removeWhere((s) => s.id == e.key);
      }
      await store.put(e.key, e.value);
    }

    final newMark = maxMark([
      mark,
      for (final s in changed) s.updatedAt,
      ...newTombs.values,
    ]);
    return _SyncResult(updated, deleted, newMark);
  }

  // ── 判定ヘルパー（テスト用に公開） ──────────────────────────────

  /// a の最終更新日時が b より新しいか。更新日時なしは最も古い扱い。
  static bool isNewer(WorkoutSession a, {required WorkoutSession than}) {
    final at = a.updatedAt;
    final bt = than.updatedAt;
    if (at == null) return false;
    if (bt == null) return true;
    return at.isAfter(bt);
  }

  /// 記録が削除の印より後に編集されているか（記録が無い・更新日時なしは false）。
  static bool isEditedAfterDeletion(WorkoutSession? s, DateTime deletedAt) {
    final u = s?.updatedAt;
    return u != null && u.isAfter(deletedAt);
  }

  /// 端末とクラウドの削除の印をまとめる（同じ ID は新しい方の時刻）。
  static Map<String, DateTime> mergeTombstones(
      Map<String, DateTime> a, Map<String, DateTime> b) {
    final m = Map<String, DateTime>.from(a);
    for (final e in b.entries) {
      final cur = m[e.key];
      if (cur == null || e.value.isAfter(cur)) m[e.key] = e.value;
    }
    return m;
  }

  /// 次回の差分同期の基準（最も新しい時刻の文字列）。
  static String? maxMark(Iterable<Object?> values) {
    String? best;
    for (final v in values) {
      final s = v is DateTime ? v.toIso8601String() : v as String?;
      if (s != null && (best == null || s.compareTo(best) > 0)) best = s;
    }
    return best;
  }
}

class _SyncResult {
  final List<WorkoutSession> updated;
  final Set<String> deleted;
  final String? newMark;
  _SyncResult(this.updated, this.deleted, this.newMark);
}
