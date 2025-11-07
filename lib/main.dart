import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

// Screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/about_screen.dart';
import 'screens/search_screen.dart';
import 'screens/users_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/display_settings_screen.dart';

// Models & Utils
import 'models/article.dart';
import 'utils/custom_page_transitions.dart';
import 'utils/theme_config.dart';
import 'utils/auth_service.dart';
import 'utils/font_cache.dart';
import 'utils/strings.dart';

// Providers
import 'providers/theme_provider.dart';
import 'providers/article_provider.dart';
import 'providers/language_provider.dart';

// Services
import 'services/notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/bookmark_service.dart';

// Widgets
import 'widgets/theme_transition_builder.dart';
import 'widgets/theme_toggle_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await NotificationService().init();
  BackgroundNotificationService().initialize();

  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLocale()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FontCache.preloadFonts(context);
    });

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        final strings = AppStrings(languageProvider.locale.languageCode);

        // --- PERUBAHAN DI SINI ---
        // Kita gunakan .copyWith() untuk menimpa warna latar belakang
        // dari tema statis Anda dengan warna dari provider.
        
        // Tema Terang menggunakan lightColor dari provider
        final lightThemeData = AppTheme.lightTheme.copyWith(
          scaffoldBackgroundColor: ThemeProvider.lightColor,
          canvasColor: ThemeProvider.lightColor, // Untuk BottomNavBar, Dialog, dll.
          bottomAppBarTheme: AppTheme.lightTheme.bottomAppBarTheme.copyWith(
            color: ThemeProvider.lightColor,
          ),
          brightness: Brightness.light,
        );

        // Tema Gelap menggunakan darkColor dari provider
        final darkThemeData = AppTheme.darkTheme.copyWith(
          scaffoldBackgroundColor: ThemeProvider.darkColor,
          canvasColor: ThemeProvider.darkColor, // Untuk BottomNavBar, Dialog, dll.
          bottomAppBarTheme: AppTheme.darkTheme.bottomAppBarTheme.copyWith(
            color: ThemeProvider.darkColor,
          ),
          brightness: Brightness.dark,
        );
        // --- AKHIR PERUBAHAN ---

        return ThemeTransitionBuilder(
          themeController: themeProvider,
          builder: (context, theme) {
            return MaterialApp(
              title: strings.appTitle,
              debugShowCheckedModeBanner: false,
              
              // Gunakan tema yang sudah kita modifikasi
              theme: lightThemeData.copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CustomPageTransitionBuilder(),
                    TargetPlatform.iOS: CustomPageTransitionBuilder(),
                  },
                ),
              ),
              darkTheme: darkThemeData,
              
              themeMode: themeProvider.themeMode,
              locale: languageProvider.locale,
              supportedLocales: const [Locale('id', '')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const MainScreen(),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    if (mounted) setState(() { _isLoggedIn = isLoggedIn; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold( body: Center( child: CircularProgressIndicator()));
    return _isLoggedIn ? const MainScreen() : const LoginScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  final BookmarkService _bookmarkService = BookmarkService();
  List<Article> _allBookmarkedArticles = [];
  bool _isLoadingBookmarks = true;
  bool _isHandlingBookmark = false;

  // Exit confirmation
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
    _loadAllBookmarks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ArticleProvider>(context, listen: false).loadArticles();
      _maybeAskNotificationPermission();
      _maybeAskLocationPermission();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBookmarks() async {
    if (mounted) setState(() => _isLoadingBookmarks = true);
    try {
      final bookmarks = await _bookmarkService.getAllBookmarkedArticlesSimple();
      if (mounted) {
        if (!listEquals(_allBookmarkedArticles.map((e)=>e.id).toList(), bookmarks.map((e)=>e.id).toList())) {
            setState(() { _allBookmarkedArticles = bookmarks; });
            debugPrint("Reloaded simple bookmarks. Count: ${bookmarks.length}");
        }
        setState(() => _isLoadingBookmarks = false);
      }
    } catch (e) {
       debugPrint("Error loading all simple bookmarks in MainScreen: $e");
       if (mounted) {
         setState(() => _isLoadingBookmarks = false);
         _showErrorSnackBar('Gagal memuat daftar bookmark');
       }
    }
  }

  Future<void> _handleBookmarkToggle(BuildContext context, Article article) async {
     if (_isHandlingBookmark) { debugPrint("Bookmark action in progress..."); return; }
     if (mounted) setState(() => _isHandlingBookmark = true);
     debugPrint("Handling simple bookmark toggle for: ${article.id}");

     final bool isCurrentlyBookmarked = _allBookmarkedArticles.any((a) => a.id == article.id);
     final authService = AuthService();
     final user = await authService.getCurrentUser();
     final bool isGuest = user == null || user['username'] == 'Guest';

     if (isGuest) {
        _showLoginRequiredSnackBar("Masuk untuk menyimpan artikel ini");
        if (mounted) setState(() => _isHandlingBookmark = false);
        return;
     }

     try {
       if (isCurrentlyBookmarked) {
          debugPrint("Attempting to remove simple bookmark...");
          bool removed = await _bookmarkService.removeBookmark(article);
          if (removed && mounted) {
             debugPrint("Bookmark removed, reloading state...");
             await _loadAllBookmarks();
             _showSuccessSnackBar('Artikel dihapus dari bookmark');
          } else {
             debugPrint("Bookmark remove reported false.");
             if(mounted) await _loadAllBookmarks();
          }
       } else {
          debugPrint("Attempting to add simple bookmark...");
          bool added = await _bookmarkService.addSimpleBookmark(article);
          if (added && mounted) {
             debugPrint("Bookmark added, reloading state...");
             await _loadAllBookmarks();
             _showSuccessSnackBar('Artikel disimpan ke bookmark');
          } else if (!added && mounted) {
             await _loadAllBookmarks();
             _showSuccessSnackBar('Artikel sudah ada di bookmark');
          }
       }
     } catch (e) {
        debugPrint("Error during simple bookmark toggle: $e");
        if (mounted) _showErrorSnackBar('Terjadi kesalahan bookmark: ${e.toString()}');
     } finally {
        debugPrint("Resetting bookmark handling flag.");
        if (mounted) setState(() => _isHandlingBookmark = false);
     }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _tabController.animateTo(index);
  }

  Future<void> _maybeAskNotificationPermission() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    final strings = AppStrings(lang);
    PermissionStatus status = await Permission.notification.status;
    debugPrint("Notification permission status: $status");

    if (status.isDenied || status.isLimited) {
      PermissionStatus requestedStatus = await Permission.notification.request();
      debugPrint("Notification permission requested, new status: $requestedStatus");
      if (requestedStatus.isGranted || requestedStatus.isLimited) {
        await BackgroundNotificationService().setNotificationsEnabled(true);
      } else if (requestedStatus.isPermanentlyDenied && mounted) {
        _showPermissionPermanentlyDeniedDialog( title: 'Notifikasi Dinonaktifkan', content: 'Untuk menerima rekomendasi artikel, silakan aktifkan notifikasi di pengaturan perangkat Anda.', strings: strings);
      }
    } else if (status.isPermanentlyDenied && mounted) {
       _showPermissionPermanentlyDeniedDialog( title: 'Notifikasi Dinonaktifkan', content: 'Untuk menerima rekomendasi artikel, silakan aktifkan notifikasi di pengaturan perangkat Anda.', strings: strings);
    } else if (status.isGranted || status.isProvisional) {
        await BackgroundNotificationService().setNotificationsEnabled(true);
        debugPrint("Notification permission already granted.");
    }
  }

  Future<void> _maybeAskLocationPermission() async {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    final strings = AppStrings(lang);
    PermissionStatus status = await Permission.locationWhenInUse.status;
     debugPrint("Location permission status: $status");

    if (status.isDenied || status.isLimited) {
      PermissionStatus requestedStatus = await Permission.locationWhenInUse.request();
       debugPrint("Location permission requested, new status: $requestedStatus");
      if (requestedStatus.isPermanentlyDenied && mounted) {
         _showPermissionPermanentlyDeniedDialog( title: 'Lokasi Dinonaktifkan', content: 'Untuk menyesuaikan berita dengan wilayah Anda, silakan aktifkan akses lokasi di pengaturan perangkat Anda.', strings: strings);
      }
    } else if (status.isPermanentlyDenied && mounted) {
      _showPermissionPermanentlyDeniedDialog( title: 'Lokasi Dinonaktifkan', content: 'Untuk menyesuaikan berita dengan wilayah Anda, silakan aktifkan akses lokasi di pengaturan perangkat Anda.', strings: strings);
    } else if (status.isGranted) {
       debugPrint("Location permission already granted.");
    }
  }

  Future<void> _showPermissionPermanentlyDeniedDialog({ required String title, required String content, required AppStrings strings }) async {
     await showDialog( context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton( onPressed: () => Navigator.of(context).pop(), child: Text(strings.cancel, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
            TextButton( onPressed: () async { Navigator.of(context).pop(); await openAppSettings(); }, child: Text('Pengaturan', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold))),
          ],
        ),
      );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: // Home
        return HomeScreen(
          bookmarkedArticles: _allBookmarkedArticles,
          onBookmarkToggle: (article) => _handleBookmarkToggle(context, article),
        );
      case 1: // Discover
        return SearchScreen(
          bookmarkedArticles: _allBookmarkedArticles,
          onBookmarkToggle: (article) => _handleBookmarkToggle(context, article),
        );
      case 2: // Account
        return AboutScreen(
          onNavigateToHome: () => _onItemTapped(0),
        );
      default:
        return Container(color: Colors.grey);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Row(children: [ const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction( label: 'TUTUP', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar())
     ));
  }

  void _showSuccessSnackBar(String message) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Row(children: [ Icon(Icons.check_circle_outline_rounded, color: Colors.green[300]), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))]),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
     ));
  }

   void _showLoginRequiredSnackBar(String message) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(
       content: Row(children: [ Icon(Icons.lock_outline_rounded, color: Colors.yellow[700]), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))]),
       backgroundColor: const Color(0xFF333333),
       behavior: SnackBarBehavior.floating,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       action: SnackBarAction( label: 'LOGIN', textColor: Colors.yellow[700], onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen())))
     ));
  }

  void _showExitConfirmationSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tekan sekali lagi untuk keluar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Jika tidak di Home (index 0), pindah ke Home dulu
    if (_selectedIndex != 0) {
      _onItemTapped(0);
      return false;
    }

    // Jika di Home, cek double tap untuk exit
    final now = DateTime.now();
    final maxDuration = const Duration(seconds: 2);
    final isWarning = _lastPressedAt == null || now.difference(_lastPressedAt!) > maxDuration;

    if (isWarning) {
      _lastPressedAt = now;
      _showExitConfirmationSnackBar();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    // --- PERUBAHAN DI SINI ---
    // Hapus variabel manual 'isDark' dan 'bottomNavBarBackground'
    // final isDark = Theme.of(context).brightness == Brightness.dark; // DIHAPUS
    // final Color bottomNavBarBackground = isDark ? Colors.black : Colors.white; // DIHAPUS

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // 'backgroundColor' DIHAPUS. Scaffold sekarang akan otomatis
        // menggunakan 'scaffoldBackgroundColor' dari tema.
        // backgroundColor: bottomNavBarBackground, // DIHAPUS
        
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(3, (index) => _buildPage(index)),
        ),
        // 'isDark' dan 'bottomNavBarBackground' tidak perlu di-pass lagi
        bottomNavigationBar: _buildBottomNavBar(), // DIHAPUS parameternya
      ),
    );
  }

  // --- PERUBAHAN DI SINI ---
  // Hapus parameter dari method
  Widget _buildBottomNavBar() { 
    // Dapatkan 'isDark' dan 'background' dari Theme.of(context)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 'canvasColor' adalah warna yang benar untuk latar belakang
    // komponen seperti BottomNavBar yang diatur di Tema global.
    final Color background = Theme.of(context).canvasColor;

    const Color activeColor = Color(0xFF00FF00);
    final Color inactiveColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;

    return Container(
      decoration: BoxDecoration(
        color: background, // Gunakan warna dari tema
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Discover',
                index: 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Account',
                index: 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
