import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/theme_toggle_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../services/api_service.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';
import 'bookmark_screen.dart';
import 'history_screen.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import 'subscribe_screen.dart';
import 'notification_settings_screen.dart';
import 'display_settings_screen.dart';
import 'feedback_screen.dart';
import '../providers/theme_provider.dart';

class AboutScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const AboutScreen({
    Key? key,
    this.onNavigateToHome,
  }) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';
  bool _isLoggedIn = false;
  String _username = 'Guest';

  @override
  void initState() {
    super.initState();
    _getPackageInfo();
    _checkLoginStatus();
  }

  Future<void> _getPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    setState(() {
      _isLoggedIn = user != null && user['username'] != 'Guest';
      _username = user?['username'] ?? 'Guest';
    });
  }

  void _navigateToHome() {
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    }
  }

  void _navigateToBookmark() {
    // Navigasi ke BookmarkScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BookmarkScreen(),
      ),
    ).then((_) {
      // Cek ulang status login setelah kembali, 
      // siapa tahu pengguna login dari prompt di BookmarkScreen
      _checkLoginStatus();
    });
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocalHistoryScreen(),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Konfirmasi Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun $_username?',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();

      if (mounted) {
        // Tidak perlu popUntil, cukup update state
        setState(() {
          _isLoggedIn = false;
          _username = 'Guest';
        });

        _showSuccessSnackBar('Berhasil logout');
      }
    }
  }

  // BARU: Snackbar helper methods dengan style yang sama seperti main.dart
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message))
          ]
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()
        )
      )
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green[300]),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))
          ]
        ),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
      )
    );
  }

  void _showLoginRequiredSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))
          ]
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'LOGIN',
          textColor: Colors.yellow[700],
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LoginScreen())
          ).then((_) => _checkLoginStatus()) // Cek status login setelah kembali
        )
      )
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[300]),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))
          ]
        ),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = context.watch<LanguageProvider>().locale.languageCode;
    final strings = AppStrings(languageCode);

    return WillPopScope(
      onWillPop: () async {
        _navigateToHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      if (_isLoggedIn) _buildUserSection(isDark),
                      const SizedBox(height: 8),
                      _buildBookmarkHistorySection(isDark),
                      const SizedBox(height: 8),
                      
                      if (!_isLoggedIn)
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: 'Log in',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            ).then((_) => _checkLoginStatus()); // Cek status login setelah kembali
                          },
                          isDark: isDark,
                          showDivider: true,
                        ),
                      
                      _buildMenuItem(
                        icon: Icons.notifications_outlined,
                        title: 'Subscribe',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscribeScreen(),
                            ),
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifications',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.palette_outlined,
                        title: 'Display settings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DisplaySettingsScreen(),
                            ),
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.email_outlined,
                        title: 'Newsletters',
                        onTap: () {
                          launchUrl(
                            Uri.parse('https://www.owrite.id/ketentuan-penggunaan/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy',
                        onTap: () {
                          launchUrl(
                            Uri.parse('https://www.owrite.id/kebijakan-privasi/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.feedback_outlined,
                        title: 'Send feedback',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FeedbackScreen(isDark: isDark)),
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: 'FAQs',
                        onTap: () {
                          launchUrl(
                            Uri.parse('https://www.owrite.id/pedoman-media-siber/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.contact_support_outlined,
                        title: 'Contact us',
                        onTap: () {
                          launchUrl(
                            Uri.parse('https://www.owrite.id/beriklan/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildMenuItem(
                        icon: Icons.groups_outlined,
                        title: 'Authors',
                        onTap: () {
                          launchUrl(
                            Uri.parse('https://www.owrite.id/redaksi/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        isDark: isDark,
                        showDivider: _isLoggedIn,
                      ),
                      
                      if (_isLoggedIn)
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Log out',
                          onTap: _handleLogout,
                          isDark: isDark,
                          showDivider: false,
                          isDestructive: true,
                        ),
                      
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'Version $_version ($_buildNumber)',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkHistorySection(bool isDark) {
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildTabButton(
              'Bookmark',
              true,
              isDark,
              _navigateToBookmark,
            ),
          ),
          _buildVerticalDotDivider(),
          Expanded(
            child: _buildTabButton(
              'History',
              false,
              isDark,
              _navigateToHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDotDivider() {
    final dividerColor = Colors.grey[400]!;

    return Container(
      width: 40,
      height: 50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              color: dividerColor,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.bookmark_outline : Icons.access_time_rounded,
            size: 24,
            color: isDark ? Colors.white : Colors.black,
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blue,
            child: Text(
              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Logged in',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    IconData? icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    required bool showDivider,
    bool hideIcon = false,
    bool isDestructive = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDestructive 
                          ? Colors.red 
                          : (isDark ? Colors.white : Colors.black),
                      fontWeight: isDestructive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDestructive 
                      ? Colors.red 
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
      ],
    );
  }
}

class LoginPromptScreen extends StatelessWidget {
  final String title;

  const LoginPromptScreen({
    Key? key,
    required this.title,
  }) : super(key: key);

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Buat akun untuk menyimpan dan mengakses $title Anda di semua perangkat.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _navigateToLogin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAEFF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _navigateToLogin(context),
                child: RichText(
                  text: TextSpan(
                    text: 'Sudah punya akun? ',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocalHistoryScreen extends StatefulWidget {
  const LocalHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LocalHistoryScreen> createState() => _LocalHistoryScreenState();
}

class _LocalHistoryScreenState extends State<LocalHistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<Article> _historyArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> rawHistory = await _historyService.getHistory();
      
      final List<Article> parsedArticles = rawHistory.map((item) {
        // PERBAIKAN: Parse tanggal dengan benar dari data yang disimpan
        DateTime publishedAt = DateTime.now();
        DateTime modifiedAt = DateTime.now();
        
        // Coba parse dari date_gmt atau publishedAt (string ISO)
        if (item['date_gmt'] != null) {
          try {
            final dateStr = item['date_gmt'].toString();
            publishedAt = DateTime.parse(dateStr.endsWith('Z') ? dateStr : dateStr + 'Z').toLocal();
          } catch (e) {
            debugPrint('Error parsing date_gmt: $e');
          }
        } else if (item['publishedAt'] != null) {
          try {
            publishedAt = DateTime.parse(item['publishedAt']).toLocal();
          } catch (e) {
            debugPrint('Error parsing publishedAt: $e');
          }
        }
        
        // Parse modified date
        if (item['modified_gmt'] != null) {
          try {
            final dateStr = item['modified_gmt'].toString();
            modifiedAt = DateTime.parse(dateStr.endsWith('Z') ? dateStr : dateStr + 'Z').toLocal();
          } catch (e) {
            modifiedAt = publishedAt;
          }
        } else if (item['modifiedAt'] != null) {
          try {
            modifiedAt = DateTime.parse(item['modifiedAt']).toLocal();
          } catch (e) {
            modifiedAt = publishedAt;
          }
        } else {
          modifiedAt = publishedAt;
        }
        
        return Article(
          id: item['id']?.toString() ?? '',
          source: Source(
            id: item['source']?['id'],
            name: item['source']?['name'] ?? 'Unknown Source',
          ),
          author: item['author'],
          title: item['title'] ?? 'No Title',
          description: item['description'],
          url: item['url'] ?? '',
          urlToImage: item['urlToImage'],
          publishedAt: publishedAt,
          modifiedAt: modifiedAt,
          content: item['content'],
          category: item['category'] ?? 'General',
          penulis: item['penulis'],
          tags: item['tags'] != null ? List<String>.from(item['tags']) : [],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _historyArticles = parsedArticles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading local history: $e");
      if (mounted) {
        setState(() {
          _historyArticles = [];
          _isLoading = false;
        });
        _showErrorSnackBar('Gagal memuat riwayat baca');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message))
          ]
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()
        )
      )
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Baru saja';
        return '${difference.inMinutes} mnt';
      }
      return '${difference.inHours} jam';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari';
    } else {
      return DateFormat('d MMM', 'id_ID').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'History',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Riwayat Baca Anda Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Artikel yang Anda baca akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _historyArticles.length,
      itemBuilder: (context, index) {
        final article = _historyArticles[index];
        return _buildHistoryItem(article, isDark);
      },
      separatorBuilder: (context, index) {
        return DottedDivider(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        );
      },
    );
  }

  Widget _buildHistoryItem(Article article, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          HeroDialogRoute(
            builder: (context) => ArticleDetailScreen(
              article: article,
              isBookmarked: false,
              onBookmarkToggle: () {},
              heroTag: 'history-${article.id}',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: CachedNetworkImage(
                    imageUrl: article.urlToImage ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_outlined, color: Colors.grey),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        article.category.toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(article.publishedAt),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Domine',
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedDivider extends StatelessWidget {
  final double height;
  final Color color;

  const DottedDivider({
    Key? key,
    this.height = 1,
    this.color = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 1.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, shape: BoxShape.rectangle),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
