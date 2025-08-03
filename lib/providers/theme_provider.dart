import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themePreferenceKey = 'theme_preference';
  
  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeChanging = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isThemeChanging => _isThemeChanging;
  
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    _isThemeChanging = true;
    notifyListeners();
    
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _saveThemePreference();
    
    // Add a small delay to allow animation to start before changing theme
    Future.delayed(const Duration(milliseconds: 100), () {
      _isThemeChanging = false;
      notifyListeners();
    });
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