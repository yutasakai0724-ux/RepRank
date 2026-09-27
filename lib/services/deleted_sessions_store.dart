import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 削除した記録（セッション）の ID と削除時刻を、端末に覚えておく。
///
/// 削除を端末間で同期するための「削除の印」。同期のとき、この印より前に更新された
/// 記録は、どの端末にあっても削除する（別端末から再アップロードされて復活するのを防ぐ）。
/// 印より後に編集された記録は、削除後に編集されたものとして残す。
class DeletedSessionsStore {
  DeletedSessionsStore._();
  static final DeletedSessionsStore instance = DeletedSessionsStore._();

  static const _key = 'deleted_sessions_v1';

  Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          if (DateTime.tryParse(e.value as String) != null)
            e.key: DateTime.parse(e.value as String),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, DateTime> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({for (final e in m.entries) e.key: e.value.toIso8601String()}),
    );
  }

  Future<void> put(String id, DateTime at) async {
    final m = await load();
    final cur = m[id];
    if (cur != null && !at.isAfter(cur)) return;
    m[id] = at;
    await _save(m);
  }

  Future<void> remove(String id) async {
    final m = await load();
    if (m.remove(id) != null) await _save(m);
  }
}
