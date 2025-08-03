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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
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

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return ThemeTransitionBuilder(
          themeController: themeProvider,
          builder: (context, theme) {
            return MaterialApp(
              title: "d'talk app",
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
    
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
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
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });

    // Load initial articles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleProvider>(context, listen: false).loadArticles();
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
        // Clear all existing bookmarks first
        _bookmarkedArticles.clear();
        // Then add only the current article
        _bookmarkedArticles.add(article);
      }
    });
  }

  // Navigate to home screen
    void _navigateToHome() {
    setState(() {
      _selectedIndex = 0;
      _tabController.animateTo(0);
    });
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

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookmark',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'About',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
