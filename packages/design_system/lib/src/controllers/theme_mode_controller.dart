import 'package:flutter/material.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeModeController({ThemeMode initialMode = ThemeMode.system})
      : _themeMode = initialMode;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggle() {
    if (_themeMode == ThemeMode.dark) {
      setMode(ThemeMode.light);
    } else {
      setMode(ThemeMode.dark);
    }
  }

  void cycle() {
    switch (_themeMode) {
      case ThemeMode.light:
        setMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        setMode(ThemeMode.light);
        break;
    }
  }
}
