import 'package:flutter/material.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/theme_toggle_button.dart';

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
    return WillPopScope(
      onWillPop: () async {
        // Automatically navigate to home screen
        _navigateToHome();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bookmarks',
            style: TextStyle(
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
                        'No bookmarks yet',
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
                        'Save articles to read them later',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      Text(
                        'You can only bookmark one article at a time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
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
                        onBookmarkToggle: () => widget.onBookmarkToggle(article),
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
