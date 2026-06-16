import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyThemeLight = 'theme_light';
  static const _keyTextScale  = 'text_scale';

  ThemeMode _themeMode = ThemeMode.dark;
  double _textScale = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isLight = prefs.getBool(_keyThemeLight) ?? false;
    _themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
    _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThemeLight, mode == ThemeMode.light);
    notifyListeners();
  }

  Future<void> setTextScale(double scale) async {
    _textScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, scale);
    notifyListeners();
  }
}
