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

  // ── 体重 ──────────────────────────────────────────────────────

  Future<double> getBodyWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBodyWeight) ?? 70.0;
  }

  Future<void> setBodyWeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBodyWeight, value);
  }

  // ── ユーザー名 ────────────────────────────────────────────────

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? 'ユーザー名';
  }

  Future<void> setUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, value);
  }

  // ── 性別 ──────────────────────────────────────────────────────

  Future<String> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender) ?? '男性';
  }

  Future<void> setGender(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, value);
  }

  // ── 休憩タイマー秒数 ───────────────────────────────────────────

  Future<int> getRestDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRestDuration) ?? 60;
  }

  Future<void> setRestDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRestDuration, seconds);
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
    raw.add('$name|${group.name}');
    await prefs.setStringList(_keyCustomExercises, raw);
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
