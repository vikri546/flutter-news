import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/error_view.dart';
import '../providers/article_provider.dart';
import '../utils/auth_service.dart';
import 'search_screen.dart';
import 'login_screen.dart';

// List of available categories
const List<String> categories = [
  'All',
  'DIGITAL',
  'EKBIS',
  'HUKUM',
  'POLITIK',
];

class HomeScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const HomeScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _previousCategory;
  bool _showCategoryNotification = false;
  String _currentUsername = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    // Add listener to hide notification after animation completes
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _animationController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showCategoryNotification = false;
                });
              }
            });
          }
        });
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUsername = user['username'] ?? '';
      });
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final articleProvider =
          Provider.of<ArticleProvider>(context, listen: false);
      articleProvider.loadMoreArticles();
    }
  }

  void _showCategoryIndicator(String category) {
    if (_previousCategory != category) {
      _previousCategory = category;
      setState(() {
        _showCategoryNotification = true;
      });
      _animationController.forward(from: 0.0);
    }
  }

  // Show exit confirmation dialog
  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Exit App'),
              content: const Text('Are you sure you want to exit the app?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  // Open URL function (placeholder)
  void _launchURL(String url) {
    // In a real app, you would use url_launcher package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final articleProvider = Provider.of<ArticleProvider>(context);

    // Check if category changed and show notification
    if (articleProvider.currentCategory != _previousCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCategoryIndicator(articleProvider.currentCategory);
      });
    }

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when back button is pressed
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          // Exit the app
          SystemNavigator.pop();
        }
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset(
            isDark
                ? 'assets/images/logo_dark.png'
                : 'assets/images/logo_light.png',
            height: 32, // Adjust height as needed
            fit: BoxFit.contain,
          ),
          centerTitle: false, // Keep logo aligned to left like the text was
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      bookmarkedArticles: widget.bookmarkedArticles,
                      onBookmarkToggle: widget.onBookmarkToggle,
                    ),
                  ),
                );
              },
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This feature upcoming')),
                  );
                },
              ),
            ),
            const ThemeToggleButton(),
          ],
        ),
        drawer: Theme(
          data: Theme.of(context).copyWith(
            // Remove rounded corners from drawer
            drawerTheme: const DrawerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero, // Make drawer rectangular
              ),
            ),
          ),
          child: Drawer(
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        isDark
                            ? 'assets/images/logo_dark.png'
                            : 'assets/images/logo_light.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      if (_currentUsername.isNotEmpty)
                        Text(
                          'Welcome, $_currentUsername',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected =
                          category == articleProvider.currentCategory;

                      return ListTile(
                        title: Text(
                          category,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.yellow[700] : null,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () {
                          articleProvider.changeCategory(category);
                          Navigator.pop(context); // Close drawer

                          // Scroll to top if needed
                          if (_scrollController.hasClients &&
                              _scrollController.offset > 0) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Articles list
            Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Provider.of<ArticleProvider>(context, listen: false)
                          .refreshArticles();
                    },
                    child: Consumer<ArticleProvider>(
                      builder: (context, articleProvider, child) {
                        final status = articleProvider.status;
                        final articles = articleProvider.articles;
                        final currentCategory = articleProvider.currentCategory;

                        // Check if the current category is one of the specified categories
                        if (['DIGITAL', 'EKBIS', 'HUKUM', 'POLITIK']
                            .contains(currentCategory)) {
                          return Center(
                            child: Text(
                              'Sorry this is empty, comeback later :)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (status == ArticleLoadingStatus.loading &&
                            articles.isEmpty) {
                          return ShimmerLoading(isDark: isDark);
                        } else if (status == ArticleLoadingStatus.error &&
                            articles.isEmpty) {
                          return ErrorView(
                            message: articleProvider.errorMessage,
                            onRetry: () => articleProvider.refreshArticles(),
                          );
                        } else if (articles.isEmpty) {
                          return const Center(
                            child: Text('No articles found in this category'),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: articles.length +
                              (articleProvider.hasMorePages ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the bottom while loading more
                            if (index == articles.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final article = articles[index];
                            final isBookmarked =
                                widget.bookmarkedArticles.contains(article);

                            return ArticleCard(
                              article: article,
                              isBookmarked: isBookmarked,
                              onBookmarkToggle: () {
                                widget.onBookmarkToggle(article);
                                // Force rebuild to update bookmark icon
                                setState(() {});
                              },
                              index: index,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Category notification with fade animation
            if (_showCategoryNotification)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FadeTransition(
                    opacity: _animation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.yellow[700],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _previousCategory ?? '',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
