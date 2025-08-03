import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        
        return IconButton(
          icon: AnimatedCrossFade(
            firstChild: const Icon(Icons.light_mode_outlined),
            secondChild: const Icon(Icons.dark_mode_outlined),
            crossFadeState: isDark 
                ? CrossFadeState.showFirst 
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        );
      },
    );
  }
}