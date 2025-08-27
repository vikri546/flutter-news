import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../utils/app_exceptions.dart';
import '../services/background_notification_service.dart';

enum ArticleLoadingStatus {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
  noMoreData,
}

class ArticleProvider with ChangeNotifier {
  final ArticleRepository _repository;
  final BackgroundNotificationService _backgroundService =
      BackgroundNotificationService();

  // Articles data
  List<Article> _articles = [];
  String _currentCategory = 'All';
  String _errorMessage = '';
  ArticleLoadingStatus _status = ArticleLoadingStatus.initial;

  // Pagination
  int _currentPage = 1;
  bool _hasMorePages = true;

  // Search
  String _searchQuery = '';
  List<Article> _searchResults = [];
  ArticleLoadingStatus _searchStatus = ArticleLoadingStatus.initial;

  // Language / country for feed
  String _countryCode = 'us';
  String get countryCode => _countryCode;

  // Previous articles for comparison
  List<Article> _previousArticles = [];
  List<Article> _bookmarkedArticles = [];

  // Getters
  List<Article> get articles => _articles;
  List<Article> get bookmarkedArticles => _bookmarkedArticles;
  String get currentCategory => _currentCategory;
  String get errorMessage => _errorMessage;
  ArticleLoadingStatus get status => _status;
  bool get hasMorePages => _hasMorePages;

  String get searchQuery => _searchQuery;
  List<Article> get searchResults => _searchResults;
  ArticleLoadingStatus get searchStatus => _searchStatus;

  ArticleProvider({ArticleRepository? repository})
      : _repository = repository ?? ArticleRepository();

  // Set country (based on language) and refresh
  Future<void> setCountryCode(String countryCode) async {
    if (_countryCode == countryCode) return;
    _countryCode = countryCode;
    _currentPage = 1;
    _hasMorePages = true;
    _articles = [];
    _status = ArticleLoadingStatus.loading;
    notifyListeners();
    await loadArticles(refresh: true);
  }

  // Load initial articles
  Future<void> loadArticles({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMorePages = true;
      _status = ArticleLoadingStatus.loading;
    } else if (_status == ArticleLoadingStatus.loading ||
        _status == ArticleLoadingStatus.loadingMore) {
      return; // Prevent multiple simultaneous requests
    } else if (_currentPage > 1) {
      _status = ArticleLoadingStatus.loadingMore;
    } else {
      _status = ArticleLoadingStatus.loading;
    }

    notifyListeners();

    try {
      final newArticles = await _repository.getArticlesByCategory(
        _currentCategory,
        forceRefresh: refresh,
        page: _currentPage,
        country: _countryCode,
      );

      if (_currentPage == 1) {
        _previousArticles = List.from(_articles);
        _articles = newArticles;

        // Check for new articles and send notifications
        if (refresh && _articles.isNotEmpty) {
          await _checkForNewArticles();
        }
      } else {
        // Filter out duplicates when adding more pages
        final uniqueNewArticles = newArticles
            .where((article) => !_articles.any((a) => a.id == article.id))
            .toList();

        _articles.addAll(uniqueNewArticles);
      }

      // Check if we've reached the end of the data
      if (newArticles.isEmpty || newArticles.length < 100) {
        _hasMorePages = false;
        _status = ArticleLoadingStatus.noMoreData;
      } else {
        _currentPage++;
        _status = ArticleLoadingStatus.loaded;
      }
    } catch (e) {
      _status = ArticleLoadingStatus.error;
      _errorMessage = e is AppException ? e.message : 'Failed to load articles';
    }

    notifyListeners();
  }

  // Check for new articles and send notifications
  Future<void> _checkForNewArticles() async {
    if (_previousArticles.isEmpty) return;

    // Find new articles (articles that weren't in the previous list)
    final newArticles = _articles
        .where((article) => !_previousArticles
            .any((prevArticle) => prevArticle.id == article.id))
        .toList();

    if (newArticles.isNotEmpty) {
      // Send breaking news notification for the first new article
      await _backgroundService.sendBreakingNewsNotification(newArticles.first);

      // If there are multiple new articles, send a trending notification
      if (newArticles.length > 1) {
        await _backgroundService.sendTrendingNotification();
      }
    }
  }

  // Change category
  Future<void> changeCategory(String category) async {
    if (_currentCategory == category) return;

    _currentCategory = category;
    _currentPage = 1;
    _hasMorePages = true;
    _articles = [];
    _status = ArticleLoadingStatus.loading;

    notifyListeners();

    // For 'All' category, ensure we're loading the main feed properly
    if (category == 'All') {
      await loadArticles(refresh: true);
    } else {
      await loadArticles();
    }
  }

  // Load more articles (pagination)
  Future<void> loadMoreArticles() async {
    if (!_hasMorePages ||
        _status == ArticleLoadingStatus.loading ||
        _status == ArticleLoadingStatus.loadingMore) {
      return;
    }

    await loadArticles();
  }

  // Refresh articles
  Future<void> refreshArticles() async {
    await loadArticles(refresh: true);
  }

  // Search articles
  Future<void> searchArticles(String query,
      {required Map<String, dynamic> dateFilter,
      required String sortBy,
      String? language}) async {
    if (query.isEmpty) {
      _searchQuery = '';
      _searchResults = [];
      _searchStatus = ArticleLoadingStatus.initial;
      notifyListeners();
      return;
    }

    if (_searchQuery == query && _searchStatus == ArticleLoadingStatus.loaded) {
      return; // Avoid duplicate searches
    }

    _searchQuery = query;
    _searchStatus = ArticleLoadingStatus.loading;

    notifyListeners();

    try {
      _searchResults = await _repository.searchArticles(
        query: query,
        language: language,
        sortBy: sortBy,
      );
      _searchStatus = ArticleLoadingStatus.loaded;

      // Send recommendation notification for search results
      if (_searchResults.isNotEmpty) {
        await _backgroundService
            .sendRecommendationNotification(_searchResults.first);
      }
    } catch (e) {
      _searchStatus = ArticleLoadingStatus.error;
      _errorMessage =
          e is AppException ? e.message : 'Failed to search articles';
    }

    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searchStatus = ArticleLoadingStatus.initial;
    notifyListeners();
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      await _repository.clearCache();
    } catch (e) {
      _errorMessage = 'Failed to clear cache';
    }
    notifyListeners();
  }

  @override
  // Bookmarks
  Future<void> getBookmarks() async {
    try {
      final bookmarks = await _repository.getBookmarks();
      _bookmarkedArticles = bookmarks;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to get bookmarks';
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(Article article) async {
    try {
      if (_bookmarkedArticles.any((a) => a.id == article.id)) {
        await _repository.removeBookmark(article.id!);
        _bookmarkedArticles.removeWhere((a) => a.id == article.id);
      } else {
        final newBookmark = await _repository.addBookmark(article);
        _bookmarkedArticles.add(newBookmark);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to toggle bookmark';
      notifyListeners();
    }
  }

  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
