import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../services/api_service.dart';
import '../utils/app_exceptions.dart';

class ArticleRepository {
  final ApiService _apiService;
  static const String _cacheKey = 'cached_articles';
  static const String _cacheCategoryKey = 'cached_category';
  static const String _cacheTimestampKey = 'cache_timestamp';

  // Cache expiration time (30 minutes)
  static const int _cacheExpirationMinutes = 30;

  ArticleRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // Get articles by category with caching
  Future<List<Article>> getArticlesByCategory(
    String category, {
    bool forceRefresh = false,
    int page = 1,
    int pageSize = 20,
    String country = 'us',
  }) async {
    // If it's the first page and not forcing refresh, try to get from cache
    if (page == 1 && !forceRefresh) {
      try {
        final cachedArticles = await _getCachedArticles(category);
        if (cachedArticles.isNotEmpty) {
          return cachedArticles;
        }
      } catch (e) {
        // If there's an error with the cache, continue to fetch from API
        print('Cache error: ${e.toString()}');
      }
    }

    // Fetch from API
    try {
      List<Article> articles;
      if (country.toLowerCase() == 'id' && category == 'All') {
        // Use everything endpoint with language=id and query=indonesia
        articles = await _apiService.searchArticles(
          query: 'indonesia',
          language: 'id',
          sortBy: 'publishedAt',
          page: page,
          pageSize: pageSize,
        );
      } else {
        articles = await _apiService.getTopHeadlines(
          country: country,
          category: category == 'All' ? null : category,
          page: page,
          pageSize: pageSize,
        );
      }

      // Cache the first page results
      if (page == 1) {
        await _cacheArticles(articles, category);
      }

      return articles;
    } catch (e) {
      // If API fails and it's the first page, try to return cached data even if expired
      if (page == 1) {
        try {
          final cachedArticles =
              await _getCachedArticles(category, ignoreExpiration: true);
          if (cachedArticles.isNotEmpty) {
            return cachedArticles;
          }
        } catch (_) {
          // If cache also fails, rethrow the original API exception
        }
      }

      rethrow;
    }
  }

  // Search articles
  Future<List<Article>> searchArticles({
    required String query,
    String? sortBy,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _apiService.searchArticles(
      query: query,
      sortBy: sortBy,
      language: language,
      page: page,
      pageSize: pageSize,
    );
  }

  // Cache articles
  Future<void> _cacheArticles(List<Article> articles, String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesJson =
          json.encode(articles.map((e) => e.toJson()).toList());

      await prefs.setString(_cacheKey, articlesJson);
      await prefs.setString(_cacheCategoryKey, category);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      throw CacheException('Failed to cache articles: ${e.toString()}');
    }
  }

  // Get cached articles
  Future<List<Article>> _getCachedArticles(String category,
      {bool ignoreExpiration = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists
      if (!prefs.containsKey(_cacheKey) ||
          !prefs.containsKey(_cacheCategoryKey) ||
          !prefs.containsKey(_cacheTimestampKey)) {
        return [];
      }

      // Check if cache is for the requested category
      final cachedCategory = prefs.getString(_cacheCategoryKey);
      if (cachedCategory != category && category != 'All') {
        return [];
      }

      // Check if cache is expired
      if (!ignoreExpiration) {
        final cacheTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        final cacheAgeMinutes = cacheAge / (1000 * 60);

        if (cacheAgeMinutes > _cacheExpirationMinutes) {
          return [];
        }
      }

      // Get cached articles
      final articlesJson = prefs.getString(_cacheKey);
      if (articlesJson == null) {
        return [];
      }

      final List<dynamic> decodedArticles = json.decode(articlesJson);
      return decodedArticles.map((e) => Article.fromJson(e)).toList();
    } catch (e) {
      throw CacheException('Failed to get cached articles: ${e.toString()}');
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheCategoryKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      throw CacheException('Failed to clear cache: ${e.toString()}');
    }
  }

  // Bookmarks
  Future<List<Article>> getBookmarks() async {
    final response = await Supabase.instance.client
        .from('bookmarks')
        .select()
        .order('created_at', ascending: false);
    if (response.error != null) {
      throw DatabaseException(response.error!.message);
    }
    return (response.data as List)
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Article> addBookmark(Article article) async {
    final response = await Supabase.instance.client.from('bookmarks').insert({
      'user_id': Supabase.instance.client.auth.currentUser!.id,
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
    if (response.error != null) {
      throw DatabaseException(response.error!.message);
    }
    return Article.fromJson(response.data[0]);
  }

  Future<void> removeBookmark(String articleId) async {
    final response = await Supabase.instance.client
        .from('bookmarks')
        .delete()
        .match({'id': articleId});
    if (response.error != null) {
      throw DatabaseException(response.error!.message);
    }
  }

  // Dispose resources
  void dispose() {
    _apiService.dispose();
  }
}
