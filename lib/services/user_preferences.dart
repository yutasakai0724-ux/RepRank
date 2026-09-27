import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';

/// ユーザー設定の永続化（SharedPreferences ラッパー）。
/// 将来 Firebase Remote Config / Firestore に移行しやすいよう
/// アクセスはこのクラス経由に統一する。
class UserPreferences {
  UserPreferences._();
  static final UserPreferences instance = UserPreferences._();

  static const _keyBodyWeight   = 'body_weight';
  static const _keyUsername     = 'username';
  static const _keyGender       = 'gender';
  static const _keyRestDuration = 'rest_duration_sec';
  static const _keyShareStats   = 'share_anonymous_stats';

  // ── 端末間の同期（SettingsSyncService）──────────────────────────
  // 同期対象の値を変更したら、変更時刻を記録して同期サービスへ知らせる。

  /// 同期対象の値が変わったときに呼ばれる（main で SettingsSyncService が登録する）。
  static void Function(String key)? onSyncedChange;

  /// 同期対象の各値の最終変更時刻を保存するキーの接頭辞。
  static const syncTimePrefix = 'sync_t_';

  Future<void> _touch(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$syncTimePrefix$key', DateTime.now().toIso8601String());
    onSyncedChange?.call(key);
  }

  // ── 体重 ──────────────────────────────────────────────────────

  Future<double> getBodyWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBodyWeight) ?? 70.0;
  }

  Future<void> setBodyWeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBodyWeight, value);
    await _touch(_keyBodyWeight);
  }

  // ── ユーザー名 ────────────────────────────────────────────────

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? 'ユーザー名';
  }

  Future<void> setUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, value);
    await _touch(_keyUsername);
  }

  // ── 性別 ──────────────────────────────────────────────────────

  Future<String> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender) ?? '男性';
  }

  Future<void> setGender(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, value);
    await _touch(_keyGender);
  }

  // ── 休憩タイマー秒数 ───────────────────────────────────────────

  Future<int> getRestDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRestDuration) ?? 60;
  }

  Future<void> setRestDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRestDuration, seconds);
    await _touch(_keyRestDuration);
  }

  // ── カスタム種目 ──────────────────────────────────────────────
  // "種目名|muscleGroup.name" の形式でリスト保存

  static const _keyCustomExercises = 'custom_exercises';

  Future<List<Map<String, dynamic>>> getCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyCustomExercises) ?? [];
    return raw.map((s) {
      final parts = s.split('|');
      if (parts.length != 2) return null;
      try {
        final group = MuscleGroup.values.firstWhere((g) => g.name == parts[1]);
        return {'name': parts[0], 'group': group};
      } catch (_) {
        return null;
      }
    }).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> addCustomExercise(String name, MuscleGroup group) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyCustomExercises) ?? [];
    if (!raw.any((s) => s.startsWith('$name|'))) {
      raw.add('$name|${group.name}');
      await prefs.setStringList(_keyCustomExercises, raw);
      await _touch(_keyCustomExercises);
    }
    // 削除済みの名前を再び追加した場合は、削除済みの印を外す
    await _setDeleted(name, false);
  }

  /// 削除した追加種目の名前。過去の記録に名前が残っていても、種目一覧へ自動で復活させない
  /// （別端末の記録から名前を補う処理の対象外にする）ために覚えておく。
  static const _keyDeletedCustom = 'deleted_custom_exercises';

  Future<Set<String>> getDeletedCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keyDeletedCustom) ?? []).toSet();
  }

  Future<void> _setDeleted(String name, bool deleted) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_keyDeletedCustom) ?? []).toSet();
    final changed = deleted ? set.add(name) : set.remove(name);
    if (changed) {
      await prefs.setStringList(_keyDeletedCustom, set.toList());
      await _touch(_keyDeletedCustom);
    }
  }

  /// 追加した種目の名前・部位を変更する。
  /// お気に入り・表示順・ルーチン内の種目名も新しい名前に更新する。
  Future<void> updateCustomExercise(
      String oldName, String newName, MuscleGroup group) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyCustomExercises) ?? [];
    final idx = raw.indexWhere((s) => s.startsWith('$oldName|'));
    final entry = '$newName|${group.name}';
    if (idx >= 0) {
      raw[idx] = entry;
    } else {
      raw.add(entry);
    }
    await prefs.setStringList(_keyCustomExercises, raw);
    await _touch(_keyCustomExercises);

    if (oldName != newName) {
      List<String> swap(List<String> l) =>
          [for (final n in l) n == oldName ? newName : n];
      await setFavoriteExercises(swap(await getFavoriteExercises()));
      await setExerciseOrder(swap(await getExerciseOrder()));
      final routines = await getRoutines();
      for (final r in routines) {
        r['exercises'] = swap(List<String>.from(r['exercises'] as List));
      }
      await saveRoutines(routines);
      await _setDeleted(oldName, true);
      await _setDeleted(newName, false);
    }
  }

  /// 追加した種目を一覧から削除する（過去の記録は残る）。
  Future<void> removeCustomExercise(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyCustomExercises) ?? [];
    raw.removeWhere((s) => s.startsWith('$name|'));
    await prefs.setStringList(_keyCustomExercises, raw);
    await _touch(_keyCustomExercises);
    await setFavoriteExercises(
        (await getFavoriteExercises()).where((n) => n != name).toList());
    await setExerciseOrder(
        (await getExerciseOrder()).where((n) => n != name).toList());
    await _setDeleted(name, true);
  }

  // ── チュートリアル表示済みフラグ ─────────────────────────────

  static const _keyTutorialSeen = 'tutorial_seen';

  Future<bool> hasTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialSeen) ?? false;
  }

  Future<void> setTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialSeen, true);
  }

  // ── プライバシーポリシー同意済みフラグ ──────────────────────
  // true = 初回同意ダイアログを表示済み（同意・拒否どちらでも true）

  static const _keyPrivacyConsented = 'privacy_consented';

  Future<bool> hasConsentedToPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyConsented) ?? false;
  }

  Future<void> setPrivacyConsented() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyConsented, true);
  }

  // ── プロフィール画像パス ──────────────────────────────────────

  static const _keyProfileImagePath = 'profile_image_path';

  Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfileImagePath);
  }

  Future<void> setProfileImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_keyProfileImagePath);
    } else {
      await prefs.setString(_keyProfileImagePath, path);
    }
  }

  // ── kg/lbs 単位設定 ────────────────────────────────────────

  static const _keyIsKg = 'is_kg_unit';

  Future<bool> getIsKg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsKg) ?? true;
  }

  Future<void> setIsKg(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsKg, value);
    await _touch(_keyIsKg);
  }

  // ── ルーチン永続化 ─────────────────────────────────────────

  static const _keyRoutines = 'routines_v1';

  Future<List<Map<String, dynamic>>> getRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyRoutines) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        final group = MuscleGroup.values.firstWhere(
          (g) => g.name == decoded['group'],
          orElse: () => MuscleGroup.chest,
        );
        result.add({
          'name': decoded['name'] as String,
          'duration': decoded['duration'] as String? ?? '—',
          'group': group,
          'exercises': List<String>.from(decoded['exercises'] as List? ?? []),
        });
      } catch (_) {}
    }
    return result;
  }

  Future<void> saveRoutines(List<Map<String, dynamic>> routines) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = routines.map((r) => jsonEncode({
      'name': r['name'],
      'duration': r['duration'],
      'group': (r['group'] as MuscleGroup).name,
      'exercises': r['exercises'],
    })).toList();
    await prefs.setStringList(_keyRoutines, raw);
    await _touch(_keyRoutines);
  }

  // ── お気に入り種目 ─────────────────────────────────────────
  // 並び替え可能なようにリスト（順序保持）で保存する。

  static const _keyFavoriteExercises = 'favorite_exercises';

  Future<List<String>> getFavoriteExercises() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFavoriteExercises) ?? [];
  }

  Future<void> setFavoriteExercises(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavoriteExercises, names);
    await _touch(_keyFavoriteExercises);
  }

  // ── 種目の表示順（部位内の並び替え） ───────────────────────
  // 部位ごとに並び替えた結果をフラットな1つのリストとして保存する。
  // 表示時は各部位でフィルタしてからこの順序でソートする。

  static const _keyExerciseOrder = 'exercise_display_order';

  Future<List<String>> getExerciseOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyExerciseOrder) ?? [];
  }

  Future<void> setExerciseOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyExerciseOrder, order);
    await _touch(_keyExerciseOrder);
  }

  // ── 休憩タイマー通知 ──────────────────────────────────────────

  static const _keyRestNotification = 'rest_notification_enabled';

  Future<bool> getRestNotification() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRestNotification) ?? false;
  }

  Future<void> setRestNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRestNotification, value);
  }

  // ── 通知の初回案内表示済みフラグ ────────────────────────────

  static const _keyNotificationPromptShown = 'notification_prompt_shown';

  Future<bool> hasShownNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationPromptShown) ?? false;
  }

  Future<void> setNotificationPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationPromptShown, true);
  }

  // ── 匿名統計データの共有許可 ────────────────────────────────
  // ヒストグラム機能のために体重比を匿名で送信することへの同意フラグ。
  // デフォルト false（明示的な opt-in が必要）。

  Future<bool> getShareStats() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShareStats) ?? false;
  }

  Future<void> setShareStats(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShareStats, value);
  }
}
