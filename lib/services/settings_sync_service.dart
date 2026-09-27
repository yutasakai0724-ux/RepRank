import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'session_manager.dart';
import 'user_preferences.dart';

/// 設定値（体重・ユーザー名・ルーチン・お気に入りなど）を端末間で同期する。
///
/// クラウドの保存先は `users/{uid}/settings/preferences`。値ごとに「値」と「最終変更時刻」を持ち、
/// **値ごとに新しい方を採用**する。ただし次の 2 つは例外:
/// - 追加した種目（custom_exercises）: 両方の和集合から、削除済みの名前を除く
///   （別々の端末で追加した種目が片方だけにならないように）
/// - 変更時刻がまだ無い端末（この機能の導入前から使っている端末）の初回:
///   ルーチンは名前で和集合をとる（どちらかの端末のルーチンが消えないように）
///
/// 端末固有の設定（通知・テーマ・文字サイズ・チュートリアル表示済みなど）は同期しない。
class SettingsSyncService {
  SettingsSyncService._();
  static final SettingsSyncService instance = SettingsSyncService._();

  /// 同期する設定のキーと、端末に保存するときの型
  static const syncedKeys = <String, _T>{
    'body_weight': _T.double_,
    'username': _T.string,
    'gender': _T.string,
    'rest_duration_sec': _T.int_,
    'is_kg_unit': _T.bool_,
    'routines_v1': _T.list,
    'favorite_exercises': _T.list,
    'exercise_display_order': _T.list,
    'custom_exercises': _T.list,
    'deleted_custom_exercises': _T.list,
  };

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  /// UserPreferences からの変更通知を受け取るよう登録する（main で呼ぶ）。
  void attach() {
    UserPreferences.onSyncedChange = (_) => _schedulePush();
  }

  /// 設定を変えたら、少し待ってからクラウドへ反映する（連続した変更はまとめる）。
  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      final user = AuthService.instance.currentUser;
      if (user != null && !user.isAnonymous) sync(user.uid);
    });
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('preferences');

  Future<void> sync(String uid) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final snap = await _doc(uid).get();
      final cloud = Map<String, dynamic>.from(
          (snap.data()?['fields'] as Map?) ?? const {});
      final prefs = await SharedPreferences.getInstance();

      final local = <String, SettingValue>{};
      final remote = <String, SettingValue>{};
      for (final key in syncedKeys.keys) {
        final lv = prefs.get(key);
        if (lv != null) {
          local[key] = SettingValue(
            _normalize(lv),
            DateTime.tryParse(prefs
                    .getString('${UserPreferences.syncTimePrefix}$key') ??
                ''),
          );
        }
        final e = cloud[key];
        if (e is Map && e['v'] != null) {
          remote[key] = SettingValue(
              _normalize(e['v']), DateTime.tryParse(e['t'] as String? ?? ''));
        }
      }

      final merged = mergeSettings(local, remote);

      // 端末へ反映（変更時刻も合わせる。setter は使わないので再送信は起きない）
      var localChanged = false;
      for (final e in merged.entries) {
        final cur = local[e.key];
        if (cur == null || !_same(cur.value, e.value.value)) {
          await _writeLocal(prefs, e.key, e.value.value);
          localChanged = true;
        }
        final t = e.value.time;
        if (t != null) {
          await prefs.setString(
              '${UserPreferences.syncTimePrefix}${e.key}', t.toIso8601String());
        }
      }

      // クラウドへ反映（内容が変わるときだけ書き込む）
      final needPush = merged.entries.any((e) {
        final r = remote[e.key];
        return r == null ||
            !_same(r.value, e.value.value) ||
            r.time != e.value.time;
      });
      if (needPush) {
        await _doc(uid).set({
          'fields': {
            for (final e in merged.entries)
              e.key: {
                'v': e.value.value,
                't': (e.value.time ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .toIso8601String(),
              },
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 体重などを表示している画面を更新する
      if (localChanged) SessionManager.instance.notifyDataChanged();
      debugPrint('[SettingsSync] done (local changed: $localChanged, '
          'pushed: $needPush)');
    } catch (e) {
      debugPrint('[SettingsSync] failed: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(sync(uid));
      }
    }
  }

  // ── マージ（テスト用に公開） ────────────────────────────────────

  /// 端末とクラウドの設定をマージする。
  static Map<String, SettingValue> mergeSettings(
    Map<String, SettingValue> local,
    Map<String, SettingValue> remote,
  ) {
    final out = <String, SettingValue>{};
    for (final key in {...local.keys, ...remote.keys}) {
      final l = local[key], r = remote[key];
      if (l == null) {
        out[key] = r!;
      } else if (r == null) {
        out[key] = l;
      } else if (l.time == null && key == 'routines_v1') {
        // 導入前から使っている端末の初回: ルーチンは名前で和集合
        out[key] = SettingValue(_unionRoutines(r.value, l.value), r.time);
      } else if (l.time == null) {
        out[key] = r; // 変更時刻の無い端末は、クラウドを優先
      } else if (r.time == null || l.time!.isAfter(r.time!)) {
        out[key] = l;
      } else {
        out[key] = r;
      }
    }

    // 追加した種目: 和集合から、採用した「削除済み」の名前を除く
    final lc = local['custom_exercises'], rc = remote['custom_exercises'];
    if (lc != null && rc != null) {
      final deleted =
          ((out['deleted_custom_exercises']?.value as List?) ?? const [])
              .cast<String>()
              .toSet();
      final winner = out['custom_exercises']!;
      final byName = <String, String>{};
      // 採用した側の部位を優先するため、採用側を後から上書き
      final other = identical(winner, lc) ? rc : lc;
      for (final list in [other.value, winner.value]) {
        for (final entry in (list as List).cast<String>()) {
          byName[entry.split('|').first] = entry;
        }
      }
      out['custom_exercises'] = SettingValue(
        [
          for (final e in byName.entries)
            if (!deleted.contains(e.key)) e.value,
        ],
        _later(lc.time, rc.time),
      );
    }
    return out;
  }

  static List<String> _unionRoutines(Object? primary, Object? secondary) {
    final result = <String>[];
    final names = <String>{};
    for (final list in [primary, secondary]) {
      for (final s in ((list as List?) ?? const []).cast<String>()) {
        String name;
        try {
          name = (jsonDecode(s) as Map)['name'] as String;
        } catch (_) {
          name = s;
        }
        if (names.add(name)) result.add(s);
      }
    }
    return result;
  }

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  static Object _normalize(Object v) =>
      v is List ? v.map((e) => e.toString()).toList() : v;

  static bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  static Future<void> _writeLocal(
      SharedPreferences prefs, String key, Object? v) async {
    switch (syncedKeys[key]!) {
      case _T.double_:
        await prefs.setDouble(key, (v as num).toDouble());
      case _T.int_:
        await prefs.setInt(key, (v as num).toInt());
      case _T.bool_:
        await prefs.setBool(key, v as bool);
      case _T.string:
        await prefs.setString(key, v as String);
      case _T.list:
        await prefs.setStringList(
            key, (v as List).map((e) => e.toString()).toList());
    }
  }
}

enum _T { double_, int_, bool_, string, list }

/// 設定値 1 件（値と最終変更時刻）。
class SettingValue {
  final Object? value;
  final DateTime? time;
  const SettingValue(this.value, this.time);
}
