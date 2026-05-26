import 'package:shared_preferences/shared_preferences.dart';

/// ユーザー設定の永続化（SharedPreferences ラッパー）。
/// 将来 Firebase Remote Config / Firestore に移行しやすいよう
/// アクセスはこのクラス経由に統一する。
class UserPreferences {
  UserPreferences._();
  static final UserPreferences instance = UserPreferences._();

  static const _keyBodyWeight = 'body_weight';
  static const _keyUsername   = 'username';
  static const _keyGender     = 'gender';

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
}
