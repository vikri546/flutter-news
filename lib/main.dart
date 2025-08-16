import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/about_screen.dart';
import 'models/article.dart';
import 'utils/custom_page_transitions.dart';
import 'utils/theme_config.dart';
import 'utils/auth_service.dart';
import 'providers/theme_provider.dart';
import 'providers/article_provider.dart';
import 'widgets/theme_transition_builder.dart';
import 'utils/font_cache.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/language_provider.dart';
import 'utils/strings.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/background_notification_service.dart';

// PERUBAHAN: Fungsi main diubah menjadi async untuk inisialisasi service
Future<void> main() async {
  // Memastikan semua binding Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();

  // Mengunci orientasi layar ke potret
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // PERUBAHAN: Inisialisasi NotificationService saat aplikasi dimulai.
  // Ini akan membuat channel notifikasi dengan suara dan getaran.
  await NotificationService().init();

  // Initialize background notification service
  BackgroundNotificationService().initialize();

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
    // Preload fonts for better performance after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FontCache.preloadFonts(context);
    });

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        final strings = AppStrings(languageProvider.locale.languageCode);
        return ThemeTransitionBuilder(
          themeController: themeProvider,
          builder: (context, theme) {
            return MaterialApp(
              title: strings.appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme.copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CustomPageTransitionBuilder(),
                    TargetPlatform.iOS: CustomPageTransitionBuilder(),
                  },
                ),
              ),
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              locale: languageProvider.locale,
              supportedLocales: const [Locale('en'), Locale('id')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AuthWrapper(),
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

    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isLoggedIn ? const MainScreen() : const LoginScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final List<Article> _bookmarkedArticles = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });

    _loadBookmarks();

    // Load initial articles and ask for permissions after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final articleProvider =
          Provider.of<ArticleProvider>(context, listen: false);
      final lang = Provider.of<LanguageProvider>(context, listen: false)
          .locale
          .languageCode;
      articleProvider.setCountryCode(lang == 'id' ? 'id' : 'us');
      articleProvider.loadArticles();
      _maybeAskNotificationPermission();
      _ensureLocationAndAdjustFeed();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
  }

  void _toggleBookmark(Article article) {
    setState(() {
      if (_bookmarkedArticles.contains(article)) {
        _bookmarkedArticles.remove(article);
      } else {
        if (_bookmarkedArticles.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Maximum 5 bookmarks. Delete one to add a new one.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _bookmarkedArticles.add(article);
        }
      }
    });
    _saveBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('bookmarks') ?? [];
    final loaded = <Article>[];
    for (final item in stored) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        loaded.add(Article.fromJson(map));
      } catch (_) {}
    }
    if (loaded.length > 5) {
      loaded.removeRange(5, loaded.length);
    }
    if (mounted) {
      setState(() {
        _bookmarkedArticles
          ..clear()
          ..addAll(loaded);
      });
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _bookmarkedArticles
        .map((a) => jsonEncode(a.toJson()))
        .toList(growable: false);
    await prefs.setStringList('bookmarks', list);
  }

  void _navigateToHome() {
    setState(() {
      _selectedIndex = 0;
      _tabController.animateTo(0);
    });
  }

  Future<void> _maybeAskNotificationPermission() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false)
        .locale
        .languageCode;
    final strings = AppStrings(lang);
    final granted = await NotificationService().requestPermissionIfNeeded();

    // Enable notifications by default if permission is granted
    if (granted) {
      await BackgroundNotificationService().setNotificationsEnabled(true);
    }

    if (!granted && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
              strings.isEn ? 'Enable Notifications?' : 'Aktifkan Notifikasi?'),
          content: Text(strings.isEn
              ? 'Allow notifications to receive article recommendations.'
              : 'Izinkan notifikasi untuk menerima rekomendasi artikel.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Enable notifications when user agrees
                await BackgroundNotificationService()
                    .setNotificationsEnabled(true);
              },
              child: Text(strings.isEn ? 'Enable' : 'Aktifkan'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _ensureLocationAndAdjustFeed() async {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false)
        .locale
        .languageCode;
    final strings = AppStrings(lang);
    final granted = await LocationService.ensurePermission();
    if (!granted && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(strings.isEn ? 'Enable Location?' : 'Aktifkan Lokasi?'),
          content: Text(strings.isEn
              ? 'Allow location to tailor news around you.'
              : 'Izinkan akses lokasi untuk menyesuaikan berita di sekitar Anda.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Anda bisa menambahkan logika untuk membuka pengaturan aplikasi di sini
              },
              child: Text(strings.isEn ? 'Enable' : 'Aktifkan'),
            ),
          ],
        ),
      );
    }
    final cc = await LocationService.getCountryCode();
    if (cc != null && mounted) {
      await Provider.of<ArticleProvider>(context, listen: false)
          .setCountryCode(cc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      HomeScreen(
        bookmarkedArticles: _bookmarkedArticles,
        onBookmarkToggle: _toggleBookmark,
      ),
      BookmarkScreen(
        bookmarkedArticles: _bookmarkedArticles,
        onBookmarkToggle: _toggleBookmark,
        onNavigateToHome: _navigateToHome,
      ),
      AboutScreen(
        onNavigateToHome: _navigateToHome,
      ),
    ];

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final strings = AppStrings(languageProvider.locale.languageCode);
        return Scaffold(
          body: TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Menonaktifkan swipe
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: strings.home,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bookmark),
                label: strings.bookmark,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.info),
                label: strings.about,
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}
