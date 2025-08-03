import 'package:flutter/material.dart';

/// Utility class to optimize font loading
class FontCache {
  /// Pre-cache fonts for better performance
  static Future<void> preloadFonts(BuildContext context) async {
    // Create a list of font families to pre-cache
    const fontFamily = 'DMSans';

    // Load specific font weight variations
    await _loadFontVariation(fontFamily, FontWeight.w400);
    await _loadFontVariation(fontFamily, FontWeight.w500);
    await _loadFontVariation(fontFamily, FontWeight.w700);

    // Trigger font loading for italics
    await _loadFontVariation(fontFamily, FontWeight.w400, isItalic: true);
    await _loadFontVariation(fontFamily, FontWeight.w500, isItalic: true);
    await _loadFontVariation(fontFamily, FontWeight.w700, isItalic: true);
  }

  /// Helper method to load specific font weight variations
  static Future<void> _loadFontVariation(String family, FontWeight weight,
      {bool isItalic = false}) async {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: 'Preloading Font',
        style: TextStyle(
          fontFamily: family,
          fontSize: 14,
          fontWeight: weight,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
  }
}
