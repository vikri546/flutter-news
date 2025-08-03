import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

class ThemeTransitionBuilder extends StatelessWidget {
  final ThemeProvider themeController;
  final Widget Function(BuildContext, ThemeData?) builder;

  const ThemeTransitionBuilder({
    Key? key,
    required this.themeController,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = themeController.isDarkMode;
    final isChanging = themeController.isThemeChanging;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      color: isDark ? Colors.black : Colors.white,
      child: builder(context, null),
    );
  }
}