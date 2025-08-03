import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Define text styles with DMSans font
  static const _defaultTextStyle = TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w400,
  );

  static final TextTheme _textTheme = TextTheme(
    displayLarge:
        _defaultTextStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
    displayMedium:
        _defaultTextStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
    displaySmall:
        _defaultTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
    headlineLarge:
        _defaultTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
    headlineMedium:
        _defaultTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w500),
    headlineSmall:
        _defaultTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
    titleLarge:
        _defaultTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium:
        _defaultTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall:
        _defaultTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: _defaultTextStyle.copyWith(fontSize: 16),
    bodyMedium: _defaultTextStyle.copyWith(fontSize: 14),
    bodySmall: _defaultTextStyle.copyWith(fontSize: 12),
    labelLarge:
        _defaultTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium:
        _defaultTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall:
        _defaultTextStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: 'DMSans',
    textTheme: _textTheme.apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: Colors.black,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.grey,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[200]!,
      selectedColor: Colors.blue.withOpacity(0.2),
      disabledColor: Colors.grey[300]!,
      labelStyle: const TextStyle(
        fontFamily: 'DMSans',
        color: Colors.black,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'DMSans',
        color: Colors.blue,
      ),
      padding: const EdgeInsets.all(8),
    ),
    dividerColor: Colors.grey[300],
    iconTheme: const IconThemeData(
      color: Colors.black87,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue,
    fontFamily: 'DMSans',
    textTheme: _textTheme.apply(
      bodyColor: Colors.white70,
      displayColor: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.grey,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2C2C2C),
      selectedColor: Colors.blue.withOpacity(0.2),
      disabledColor: Colors.grey[700]!,
      labelStyle: const TextStyle(
        fontFamily: 'DMSans',
        color: Colors.white,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'DMSans',
        color: Colors.blue,
      ),
      padding: const EdgeInsets.all(8),
    ),
    dividerColor: Colors.grey[800],
    iconTheme: const IconThemeData(
      color: Colors.white70,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  );
}
