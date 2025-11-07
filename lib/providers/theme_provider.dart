import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themePreferenceKey = 'theme_preference';
  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeChanging = false;

  // Define primary colors for dark/light backgrounds
  static const Color darkColor = Color(0xFF020e13);
  static const Color lightColor = Color(0xFFf5f6f7);

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isThemeChanging => _isThemeChanging;

  // Convenient getter for dark mode detection
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // Use the custom background color depending on theme
  Color get backgroundColor =>
      isDarkMode ? darkColor : lightColor;

  void setThemeMode(ThemeMode mode) {
    _isThemeChanging = true;
    notifyListeners();

    _themeMode = mode;
    _saveThemePreference();

    Future.delayed(const Duration(milliseconds: 100), () {
      _isThemeChanging = false;
      notifyListeners();
    });
  }

  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePreferenceKey);
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_themeMode == ThemeMode.dark) {
      await prefs.setString(_themePreferenceKey, 'dark');
    } else if (_themeMode == ThemeMode.light) {
      await prefs.setString(_themePreferenceKey, 'light');
    } else {
      await prefs.setString(_themePreferenceKey, 'system');
    }
  }
}
