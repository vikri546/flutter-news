import 'package:flutter/material.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/theme_toggle_button.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../utils/strings.dart';

class BookmarkScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;
  final VoidCallback? onNavigateToHome;

  const BookmarkScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
    this.onNavigateToHome,
  }) : super(key: key);

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<Article> _articles;

  @override
  void initState() {
    super.initState();
    _articles = List.from(widget.bookmarkedArticles);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BookmarkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle additions
    for (var article in widget.bookmarkedArticles) {
      if (!_articles.contains(article)) {
        _addArticle(article);
      }
    }

    // Handle removals
    List<Article> toRemove = [];
    for (var article in _articles) {
      if (!widget.bookmarkedArticles.contains(article)) {
        toRemove.add(article);
      }
    }

    for (var article in toRemove) {
      _removeArticle(article);
    }
  }

  void _addArticle(Article article) {
    setState(() {
      final index = _articles.length;
      _articles.add(article);
      if (_listKey.currentState != null) {
        _listKey.currentState!.insertItem(index);
      }
    });
  }

  void _removeArticle(Article article) {
    final index = _articles.indexOf(article);
    if (index >= 0) {
      final removedItem = _articles[index];
      setState(() {
        _articles.removeAt(index);
      });

      if (_listKey.currentState != null) {
        _listKey.currentState!.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(
              opacity: animation,
              child: ArticleCard(
                article: removedItem,
                isBookmarked: true,
                onBookmarkToggle: () {},
                index: index,
              ),
            ),
          ),
        );
      }
    }
  }

  // Navigate to home screen
  void _navigateToHome() {
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    return WillPopScope(
      onWillPop: () async {
        // Automatically navigate to home screen
        _navigateToHome();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            strings.bookmarksTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: const [
            ThemeToggleButton(),
          ],
        ),
        body: widget.bookmarkedArticles.isEmpty
            ? Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.yellow[600]
                            : Colors.yellow[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.noBookmarksYet,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.saveUpTo5,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.format_quote,
                              size: 24,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.yellow[600]
                                  : Colors.yellow[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context
                                          .watch<LanguageProvider>()
                                          .locale
                                          .languageCode ==
                                      'id'
                                  ? '"Membaca berita adalah cara terbaik untuk memahami dunia di sekitar kita dan tetap terhubung dengan realitas yang terus berubah."'
                                  : '"Reading news is the best way to understand the world around us and stay connected with the ever-changing reality."',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : AnimatedList(
                key: _listKey,
                initialItemCount: _articles.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index, animation) {
                  final article = _articles[index];
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(
                      opacity: animation,
                      child: ArticleCard(
                        article: article,
                        isBookmarked: true,
                        onBookmarkToggle: () =>
                            widget.onBookmarkToggle(article),
                        index: index,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
