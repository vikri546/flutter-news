import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../utils/app_exceptions.dart';

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

  // Getters
  List<Article> get articles => _articles;
  String get currentCategory => _currentCategory;
  String get errorMessage => _errorMessage;
  ArticleLoadingStatus get status => _status;
  bool get hasMorePages => _hasMorePages;

  String get searchQuery => _searchQuery;
  List<Article> get searchResults => _searchResults;
  ArticleLoadingStatus get searchStatus => _searchStatus;

  ArticleProvider({ArticleRepository? repository})
      : _repository = repository ?? ArticleRepository();

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
      );

      if (_currentPage == 1) {
        _articles = newArticles;
      } else {
        // Filter out duplicates when adding more pages
        final uniqueNewArticles = newArticles
            .where((article) => !_articles.any((a) => a.id == article.id))
            .toList();

        _articles.addAll(uniqueNewArticles);
      }

      // Check if we've reached the end of the data
      if (newArticles.isEmpty || newArticles.length < 20) {
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
  Future<void> searchArticles(String query, {required Map<String, dynamic> dateFilter, required String sortBy}) async {
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
      _searchResults = await _repository.searchArticles(query: query);
      _searchStatus = ArticleLoadingStatus.loaded;
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
    await _repository.clearCache();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
