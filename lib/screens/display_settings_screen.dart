import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart'; // Pastikan path ini benar

enum TextSize { small, medium, large }

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({Key? key}) : super(key: key);

  // Warna hijau stabilo kustom Anda
  static const Color _stabiloGreen = Color(0xFFAEFF00);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final inactiveBorderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    // Mengamati perubahan pada ThemeProvider
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;
    final isAutomatic = currentMode == ThemeMode.system;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Display settings',
          style: TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // --- Bagian THEME ---
          _buildSectionHeader("THEME", isDark),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              "Gunakan pengaturan perangkat Anda untuk menentukan tampilan aplikasi atau atur default di bawah.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          
          SwitchListTile(
            title: const Text(
              "Automatic",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Gunakan state dari provider
            value: isAutomatic,
            onChanged: (bool value) {
              // Panggil metode provider (menggunakan 'read' di dalam callback)
              if (value) {
                context.read<ThemeProvider>().setThemeMode(ThemeMode.system);
              } else {
                // Jika mematikan automatic, kembali ke mode non-sistem terakhir
                // atau default ke 'light' jika belum pernah diubah.
                context.read<ThemeProvider>().setThemeMode(ThemeMode.light);
              }
            },
            activeColor: _stabiloGreen,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(height: 16),

          // --- Pilihan Light / Dark ---
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  context,
                  "Light",
                  ThemeMode.light,
                  isDark,
                  inactiveBorderColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildThemeCard(
                  context,
                  "Dark",
                  ThemeMode.dark,
                  isDark,
                  inactiveBorderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- Bagian TEXT SIZE ---
          _buildSectionHeader("TEXT SIZE", isDark),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Text(
              "Aplikasi mengikuti pengaturan perangkat untuk ukuran font. Aplikasi akan diperbarui apabila pengaturan perangkat Anda berubah.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),

          // --- Tombol Settings ---
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Belum diimplementasikan'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: isDark ? Colors.white : Colors.black,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.white : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
            ),
            child: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget untuk header (THEME, TEXT SIZE)
  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.grey[500] : Colors.grey[600],
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  // Helper widget untuk kartu pilihan tema
  Widget _buildThemeCard(BuildContext context, String title, ThemeMode mode, bool isDark, Color inactiveBorderColor) {
    // Baca state langsung dari provider
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;
    final bool isSelected = currentMode == mode && currentMode != ThemeMode.system;
    
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Panggil metode provider
        context.read<ThemeProvider>().setThemeMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isSelected ? _stabiloGreen : inactiveBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Visual representasi tema ---
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: mode == ThemeMode.light ? const Color(0xFFE0E0E0) : const Color(0xFF303030),
                border: Border.all(color: mode == ThemeMode.light ? Colors.grey[400]! : Colors.grey[700]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 25,
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: mode == ThemeMode.light ? Colors.white : const Color(0xFF424242),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: mode == ThemeMode.light ? Colors.grey[300]! : Colors.grey[600]!)
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 30,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      color: _stabiloGreen,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // --- Radio button dan Teks ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Radio<ThemeMode>(
                  value: mode,
                  // Tentukan grup berdasarkan state provider
                  groupValue: currentMode == ThemeMode.system ? null : currentMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      context.read<ThemeProvider>().setThemeMode(value);
                    }
                  },
                  activeColor: _stabiloGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}