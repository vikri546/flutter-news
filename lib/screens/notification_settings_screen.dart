import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_scheduler.dart';
import '../providers/theme_provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Toggle "Tetap Terinformasi"
  bool _breakingNews = true;
  bool _topBusinessStories = true;
  bool _topNewsStories = true;

  // Toggle Berita Kurasi (kategori API)
  bool _hype = false;        // Kategori HYPE
  bool _olahraga = false;    // Kategori OLAHRAGA
  bool _ekbis = false;       // Kategori EKBIS
  bool _megapolitan = false; // Kategori MEGAPOLITAN
  bool _daerah = false;      // Kategori DAERAH
  bool _nasional = false;    // Kategori NASIONAL
  bool _internasional = false; // Kategori INTERNASIONAL

  // Cek apakah notifikasi diizinkan pengguna di aplikasi (custom logic)
  bool _notificationsEnabled = false;

  // Warna stabilo hijau yang diminta
  static const Color _stabiloGreen = Color(0xFFAEEE00);

  final NotificationScheduler _scheduler = NotificationScheduler();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkNotificationPermission();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _breakingNews = prefs.getBool('notif_breaking_news') ?? true;
      _topBusinessStories = prefs.getBool('notif_top_business') ?? true;
      _topNewsStories = prefs.getBool('notif_top_news') ?? true;
      // Muat preferensi kategori
      _hype = prefs.getBool('notif_category_HYPE') ?? false;
      _olahraga = prefs.getBool('notif_category_OLAHRAGA') ?? false;
      _ekbis = prefs.getBool('notif_category_EKBIS') ?? false;
      _megapolitan = prefs.getBool('notif_category_MEGAPOLITAN') ?? false;
      _daerah = prefs.getBool('notif_category_DAERAH') ?? false;
      _nasional = prefs.getBool('notif_category_NASIONAL') ?? false;
      _internasional = prefs.getBool('notif_category_INTERNASIONAL') ?? false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    // Update penjadwalan notifikasi ketika preferensi berubah
    await _scheduler.updateCategoryPreferences();
  }

  Future<void> _saveCategoryPreference(String category, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_category_$category', value);
    // Update penjadwalan notifikasi
    await _scheduler.updateCategoryPreferences();
  }

  Future<void> _checkNotificationPermission() async {
    // Atur status notifikasi enabled melalui NotificationScheduler (atau platform API yang lain)
    final enabled = await _scheduler.isPermissionGranted();
    if (mounted) {
      // Jika terjadi perubahan dari aktif ke nonaktif, auto-nonaktifkan semua kategori pilihan
      bool prev = _notificationsEnabled;
      setState(() {
        _notificationsEnabled = enabled;
      });
      if (prev && !enabled) {
        await _resetKategoriPilihan();
      }
    }
  }

  void _requestNotificationPermissions() async {
    await _scheduler.setNotificationsEnabled(true);
    await _scheduler.requestPermissionIfNeeded();
    await _checkNotificationPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Notifikasi diaktifkan'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _disableNotificationPermissions() async {
    // Custom logic to disable notifications in the app scope
    await _scheduler.setNotificationsEnabled(false);

    // Reset semua preferensi (kategori pilihan otomatis nonaktif)
    await _resetAllPreferences();

    await _checkNotificationPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.white),
              SizedBox(width: 12),
              Text('Notifikasi dinonaktifkan'),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _resetAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Reset all to defaults and kategori pilihan auto-off ketika nonaktifkan notifikasi
    setState(() {
      _breakingNews = true;
      _topBusinessStories = true;
      _topNewsStories = true;
      _hype = false;
      _olahraga = false;
      _ekbis = false;
      _megapolitan = false;
      _daerah = false;
      _nasional = false;
      _internasional = false;
    });
    await prefs.setBool('notif_breaking_news', true);
    await prefs.setBool('notif_top_business', true);
    await prefs.setBool('notif_top_news', true);
    await prefs.setBool('notif_category_HYPE', false);
    await prefs.setBool('notif_category_OLAHRAGA', false);
    await prefs.setBool('notif_category_EKBIS', false);
    await prefs.setBool('notif_category_MEGAPOLITAN', false);
    await prefs.setBool('notif_category_DAERAH', false);
    await prefs.setBool('notif_category_NASIONAL', false);
    await prefs.setBool('notif_category_INTERNASIONAL', false);
    // Optionally stop scheduler/notifications, if your service supports it
    await _scheduler.updateCategoryPreferences();
  }

  /// Reset hanya kategori pilihan (digunakan saat permission dicabut atau dinonaktifkan)
  Future<void> _resetKategoriPilihan() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hype = false;
      _olahraga = false;
      _ekbis = false;
      _megapolitan = false;
      _daerah = false;
      _nasional = false;
      _internasional = false;
    });
    await prefs.setBool('notif_category_HYPE', false);
    await prefs.setBool('notif_category_OLAHRAGA', false);
    await prefs.setBool('notif_category_EKBIS', false);
    await prefs.setBool('notif_category_MEGAPOLITAN', false);
    await prefs.setBool('notif_category_DAERAH', false);
    await prefs.setBool('notif_category_NASIONAL', false);
    await prefs.setBool('notif_category_INTERNASIONAL', false);
    await _scheduler.updateCategoryPreferences();
  }

  void _showDisableNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nonaktifkan Notifikasi?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menonaktifkan notifikasi aplikasi? Anda tidak akan menerima berita terbaru dan pembaruan.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _disableNotificationPermissions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Nonaktifkan'),
            ),
          ],
        );
      },
    ).then((_) {
      _checkNotificationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blocked = !_notificationsEnabled;

    // Bagian TETAP TERINFORMASI: SELALU enabled/tidak pernah tergantung izin notifikasi
    final sectionTetapTerinformasiEnabled = true;
    // Bagian kategori hanya enabled jika notification benar-benar aktif
    final sectionKategoriEnabled = !blocked && _notificationsEnabled;

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Teks deskripsi
          Text(
            'Aktifkan notifikasi untuk mendapatkan berita terkini sesuai topik favoritmu.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Tombol izinkan notifikasi ATAU nonaktifkan
          InkWell(
            onTap: () {
              if (blocked) {
                _showAllowNotificationsDialog();
              } else {
                _showDisableNotificationsDialog();
              }
            },
            child: Row(
              children: [
                Icon(
                  blocked
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 21,
                  color: blocked ? Colors.yellow[500] : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  blocked
                      ? 'Izinkan notifikasi'
                      : 'Nonaktifkan notifikasi',
                  style: TextStyle(
                    fontSize: 16,
                    color: blocked ? Colors.yellow[500] : Colors.grey[400],
                    fontWeight: FontWeight.w600,
                    decoration: blocked ? null : null,
                  ),
                ),
              ],
            ),
          ),
          if (!blocked)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Notifikasi aktif. Tekan untuk menonaktifkan.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Bagian TETAP TERINFORMASI
          Text(
            'TETAP TERINFORMASI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Selalu enabled walaupun izin notif tidak tersedia
          _buildToggleItem(
            title: 'Berita terkini',
            value: _breakingNews,
            onChanged: (value) {
              setState(() => _breakingNews = value);
              _savePreference('notif_breaking_news', value);
            },
            isDark: isDark,
            enabled: true,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Berita bisnis teratas',
            value: _topBusinessStories,
            onChanged: (value) {
              setState(() => _topBusinessStories = value);
              _savePreference('notif_top_business', value);
            },
            isDark: isDark,
            enabled: true,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Berita utama',
            value: _topNewsStories,
            onChanged: (value) {
              setState(() => _topNewsStories = value);
              _savePreference('notif_top_news', value);
            },
            isDark: isDark,
            enabled: true,
          ),

          const SizedBox(height: 40),

          // Bagian BERITA KURASI (berdasarkan kategori)
          Text(
            'BERITA KATEGORI PILIHAN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Semua kategori berita akan always disabled jika notification nonaktif
          _buildToggleItem(
            title: 'Hype',
            value: _hype,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _hype = value);
                    _saveCategoryPreference('HYPE', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Olahraga',
            value: _olahraga,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _olahraga = value);
                    _saveCategoryPreference('OLAHRAGA', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Ekonomi & Bisnis',
            value: _ekbis,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _ekbis = value);
                    _saveCategoryPreference('EKBIS', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Megapolitan',
            value: _megapolitan,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _megapolitan = value);
                    _saveCategoryPreference('MEGAPOLITAN', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Daerah',
            value: _daerah,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _daerah = value);
                    _saveCategoryPreference('DAERAH', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Nasional',
            value: _nasional,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _nasional = value);
                    _saveCategoryPreference('NASIONAL', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),
          _buildDottedDivider(isDark),

          _buildToggleItem(
            title: 'Internasional',
            value: _internasional,
            onChanged: (sectionKategoriEnabled)
                ? (value) {
                    setState(() => _internasional = value);
                    _saveCategoryPreference('INTERNASIONAL', value);
                  }
                : null,
            isDark: isDark,
            enabled: sectionKategoriEnabled,
          ),

          if (blocked)
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900]?.withOpacity(0.75) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aktifkan izin notifikasi terlebih dahulu untuk memilih kategori berita favorit.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required bool isDark,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !enabled,
              child: Switch(
                value: value,
                onChanged: onChanged != null
                    ? (val) async {
                        // Khusus untuk bagian tetap terinformasi: switches selalu bisa diubah, tidak tergantung izin notif.
                        // Untuk bagian kategori saja yang tergantung izin.
                        if (enabled && onChanged != null) {
                          onChanged(val);
                        } else if (!_notificationsEnabled) {
                          // Switch kategori (bukan "tetap terinformasi") ketika notifikasi tidak diizinkan
                          await _resetKategoriPilihan();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Aktifkan izin notifikasi terlebih dahulu.'),
                                  ],
                                ),
                                backgroundColor: Colors.orange[800],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                        // else do nothing
                      }
                    : null,
                activeColor: _stabiloGreen,
                activeTrackColor: _stabiloGreen.withOpacity(0.35),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 2.0;
          const dashSpace = 4.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  void _showAllowNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Aktifkan Notifikasi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Izinkan aplikasi ini mengirimkan notifikasi tentang berita terkini dan pembaruan berdasarkan kategori pilihan Anda?',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Nanti saja',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Aktifkan notifikasi dan mulai scheduler
                _requestNotificationPermissions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Izinkan'),
            ),
          ],
        );
      },
    ).then((_) {
      // Setiap kali user tutup dialog, cek ulang permission
      _checkNotificationPermission();
    });
  }
}