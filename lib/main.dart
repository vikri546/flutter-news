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
import 'providers/theme_provider.dart';
import 'providers/article_provider.dart';
import 'widgets/theme_transition_builder.dart';
import 'utils/font_cache.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/language_provider.dart';
import 'utils/strings.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/background_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_credentials.dart';
import 'providers/home_screen_provider.dart';

// PERUBAHAN: Fungsi main diubah menjadi async untuk inisialisasi service
Future<void> main() async {
  // Memastikan semua binding Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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
        ChangeNotifierProvider(create: (_) => HomeScreenProvider()),
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
                useMaterial3: true,
              ),
              darkTheme: AppTheme.darkTheme.copyWith(
                useMaterial3: true,
              ),
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
  @override
  void initState() {
    super.initState();
    _redirectBasedOnAuthState();
  }

  Future<void> _redirectBasedOnAuthState() async {
    // Wait for the widget to be fully built before navigating
    await Future.delayed(Duration.zero);

    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    if (session != null) {
      // User is logged in, navigate to the main screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      // User is not logged in, navigate to the login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to handle login/logout events
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        _redirectBasedOnAuthState();
      }
    });

    // Show a loading indicator while checking auth state
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
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

    _getBookmarks();

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

  Future<void> _getBookmarks() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance
        .client
        .from('bookmarks')
        .select()
        .eq('user_id', userId);

    if (response.error == null) {
      final articles = (response.data as List)
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _bookmarkedArticles
          ..clear()
          ..addAll(articles);
      });
    }
  }

  Future<void> _toggleBookmark(Article article) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final isBookmarked =
        _bookmarkedArticles.any((element) => element.url == article.url);

    if (isBookmarked) {
      final bookmarkedArticle = _bookmarkedArticles
          .firstWhere((element) => element.url == article.url);
      await Supabase.instance
          .client
          .from('bookmarks')
          .delete()
          .match({'id': bookmarkedArticle.id});
      setState(() {
        _bookmarkedArticles.remove(bookmarkedArticle);
      });
    } else {
      final response =
          await Supabase.instance.client.from('bookmarks').insert({
        'user_id': userId,
        'article_source_id': article.source.id,
        'article_source_name': article.source.name,
        'author': article.author,
        'title': article.title,
        'description': article.description,
        'url': article.url,
        'url_to_image': article.urlToImage,
        'published_at': article.publishedAt?.toIso8601String(),
        'content': article.content,
      }).select();

      if (response.error == null) {
        final newArticle = Article.fromJson(response.data[0]);
        setState(() {
          _bookmarkedArticles.add(newArticle);
        });
      }
    }
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
          bottomNavigationBar: NavigationBar(
            onDestinationSelected: _onItemTapped,
            selectedIndex: _selectedIndex,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: strings.home,
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: strings.bookmark,
              ),
              NavigationDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: strings.about,
              ),
            ],
          ),
        );
      },
    );
  }
}
