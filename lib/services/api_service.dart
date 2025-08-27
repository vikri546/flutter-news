import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../utils/app_exceptions.dart';

class ApiService {
  final SupabaseClient _client;

  ApiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Article>> getTopHeadlines({
    String country = 'us',
    String? category,
    int page = 1,
    int pageSize = 100,
  }) async {
    return _invokeFunction(
      'top-headlines',
      {
        'country': country,
        'category': category,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
  }

  Future<List<Article>> searchArticles({
    required String query,
    String? sortBy,
    String? language,
    int page = 1,
    int pageSize = 100,
  }) async {
    return _invokeFunction(
      'everything',
      {
        'q': query,
        'sortBy': sortBy,
        'language': language,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
  }

  Future<List<Article>> getArticlesByCategory(String category,
      {int page = 1, int pageSize = 100}) async {
    if (category == 'All') {
      return getTopHeadlines(page: page, pageSize: pageSize);
    }
    return getTopHeadlines(
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<Article>> _invokeFunction(
      String endpoint, Map<String, dynamic> params) async {
    try {
      final response = await _client.functions.invoke(
        'fetch_articles',
        body: {'endpoint': endpoint, ...params},
      );

      if (response.status == 200) {
        final jsonData = json.decode(response.data);
        if (jsonData['status'] == 'ok') {
          final List<dynamic> articles = jsonData['articles'];
          return articles
              .map((article) => Article.fromJson(article))
              .toList();
        } else {
          throw ApiException(jsonData['message'] ?? 'Failed to load articles');
        }
      } else {
        throw ApiException(
            'Failed to load articles. Status code: ${response.status}');
      }
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw UnknownException('An unexpected error occurred: ${e.toString()}');
    }
  }

  void dispose() {
    // No need to dispose the client, as it's managed by the Supabase singleton.
  }
}
