import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/error_view.dart';
import '../providers/article_provider.dart';
import '../utils/strings.dart';
import 'search_screen.dart';
import 'login_screen.dart';
import '../providers/language_provider.dart';
import 'notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// List of available categories
const List<String> categories = [
  'All',
  'DIGITAL',
  'EKBIS',
  'HUKUM',
  'POLITIK',
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeScreenProvider()..loadCurrentUser(),
      child: const HomeScreenContent(),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({Key? key}) : super(key: key);

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HomeScreenProvider>(context, listen: false);
    provider.initAnimationController(this);
    _scrollController.addListener(_onScroll);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: provider.animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final articleProvider = Provider.of<ArticleProvider>(context);
    final homeScreenProvider = Provider.of<HomeScreenProvider>(context);

    if (articleProvider.currentCategory != homeScreenProvider.previousCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        homeScreenProvider.showCategoryIndicator(articleProvider.currentCategory);
      });
    }

    return WillPopScope(
      onWillPop: () async {
        final shouldExit =
            await homeScreenProvider.showExitConfirmationDialog(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset(
            isDark
                ? 'assets/images/logo_dark.png'
                : 'assets/images/logo_light.png',
            height: 32,
            fit: BoxFit.contain,
          ),
          centerTitle: false,
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
                    builder: (context) => SearchScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            const ThemeToggleButton(),
          ],
        ),
        drawer: Theme(
          data: Theme.of(context).copyWith(
            drawerTheme: const DrawerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          child: Drawer(
            child: Column(
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
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
                      if (homeScreenProvider.currentUsername.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final strings = AppStrings(context
                                .watch<LanguageProvider>()
                                .locale
                                .languageCode);
                            return Text(
                              '${strings.welcome}, ${homeScreenProvider.currentUsername}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            );
                          },
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
                          Navigator.pop(context);

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
                Builder(
                  builder: (context) {
                    final lang = context
                        .watch<LanguageProvider>()
                        .locale
                        .languageCode
                        .toUpperCase();
                    final strings = AppStrings(
                        context.watch<LanguageProvider>().locale.languageCode);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        child: Text(
                          lang,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(strings.language),
                      subtitle: Text(
                          lang == 'EN' ? strings.english : strings.indonesian),
                      onTap: () async {
                        await context.read<LanguageProvider>().toggleLocale();
                        final newLang = context
                            .read<LanguageProvider>()
                            .locale
                            .languageCode;
                        await context
                            .read<ArticleProvider>()
                            .setCountryCode(newLang == 'id' ? 'id' : 'us');
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Builder(
                    builder: (context) {
                      final strings = AppStrings(context
                          .watch<LanguageProvider>()
                          .locale
                          .languageCode);
                      return Text(strings.logout);
                    },
                  ),
                  onTap: () => homeScreenProvider.logout(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
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

                        final strings = AppStrings(
                            context.watch<LanguageProvider>().locale.languageCode);
                        if (['DIGITAL', 'EKBIS', 'HUKUM', 'POLITIK']
                            .contains(currentCategory)) {
                          return Center(
                            child: Text(
                              strings.emptyCategory,
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
                          return Center(
                            child: Text(strings.noArticlesFound),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: articles.length +
                              (articleProvider.hasMorePages ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == articles.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final article = articles[index];
                            final isBookmarked = articleProvider
                                .bookmarkedArticles
                                .any((a) => a.id == article.id);

                            return ArticleCard(
                              article: article,
                              isBookmarked: isBookmarked,
                              onBookmarkToggle: () {
                                articleProvider.toggleBookmark(article);
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
            if (homeScreenProvider.showCategoryNotification)
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
                        homeScreenProvider.previousCategory,
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
