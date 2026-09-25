import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../repositories/firestore_workout_repository.dart';
import '../repositories/sqlite_workout_repository.dart';
import '../data/database_helper.dart';
import 'session_manager.dart';

/// ログイン時のデータ同期を管理するサービス。
///
/// 端末（SQLite）とクラウド（Firestore）を双方向にマージする。
/// - 端末にしかない記録 → クラウドへアップロード
/// - クラウドにしかない記録 → 端末へダウンロード
/// - 両方にある記録（同じセッションID） → 最終更新日時が新しい方を両方に反映
///   （更新日時が無い古いデータ同士は、従来どおり端末側を優先）
///
/// 削除の同期は行わない（他端末で削除した記録が、別端末から再アップロードされる場合がある）。
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Future<void> syncOnLogin(String uid) async {
    try {
      debugPrint('[Sync] starting sync for uid=$uid');
      final local = SqliteWorkoutRepository(DatabaseHelper.instance);
      final cloud = FirestoreWorkoutRepository(uid);

      final localById = {for (final s in await local.getAllSessions()) s.id: s};
      final cloudById = {for (final s in await cloud.getAllSessions()) s.id: s};

      var uploaded = 0;
      var downloaded = 0;

      for (final l in localById.values) {
        final c = cloudById[l.id];
        if (c == null) {
          await cloud.upsertSession(l);
          uploaded++;
        } else if (_isNewer(c, than: l)) {
          await local.upsertSession(c);
          downloaded++;
        } else if (_isNewer(l, than: c) || (l.updatedAt == null && c.updatedAt == null)) {
          await cloud.upsertSession(l);
          uploaded++;
        }
      }

      for (final c in cloudById.values) {
        if (!localById.containsKey(c.id)) {
          await local.upsertSession(c);
          downloaded++;
        }
      }

      debugPrint('[Sync] done: uploaded=$uploaded downloaded=$downloaded');
      if (downloaded > 0) SessionManager.instance.notifyDataChanged();
    } catch (e) {
      debugPrint('[Sync] sync failed: $e');
    }
  }

  /// a の最終更新日時が b より新しいか。更新日時なしは最も古い扱い。
  bool _isNewer(WorkoutSession a, {required WorkoutSession than}) {
    final at = a.updatedAt;
    final bt = than.updatedAt;
    if (at == null) return false;
    if (bt == null) return true;
    return at.isAfter(bt);
  }
}
