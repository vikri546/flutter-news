import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../utils/app_exceptions.dart';

class ApiService {
  //  API URL and key
  static const String _baseUrl =
      'https://newsapi.org/v2';
  static const String _apiKey =
      '5593fe2ec6c3423e8c395f4382f77192'; //  API key

  // HTTP client for making requests
  final http.Client _client;

  // Constructor with optional client parameter for testing
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Get top headlines
  Future<List<Article>> getTopHeadlines({
    String country = 'us',
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    Map<String, String> queryParameters = {
      'country': country,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'apiKey': _apiKey,
    };

    if (category != null && category != 'All') {
      queryParameters['category'] = category.toLowerCase();
    }

    return _getArticles('/top-headlines', queryParameters);
  }

  // Search articles
  Future<List<Article>> searchArticles({
    required String query,
    String? sortBy,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    Map<String, String> queryParameters = {
      'q': query,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'apiKey': _apiKey,
    };

    if (sortBy != null) {
      queryParameters['sortBy'] = sortBy;
    }

    if (language != null) {
      queryParameters['language'] = language;
    }

    return _getArticles('/everything', queryParameters);
  }

  // Get articles by category
  Future<List<Article>> getArticlesByCategory(String category,
      {int page = 1, int pageSize = 20}) async {
    if (category == 'All') {
      return getTopHeadlines(page: page, pageSize: pageSize);
    }

    return getTopHeadlines(
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  // Helper method to make GET requests and parse articles
  Future<List<Article>> _getArticles(
      String endpoint, Map<String, String> queryParameters) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint')
          .replace(queryParameters: queryParameters);

      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timeout. Please try again.');
        },
      );

      return _processResponse(response);
    } on SocketException {
      throw NoInternetException(
          'No internet connection. Please check your network.');
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw UnknownException('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Process HTTP response
  List<Article> _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      if (jsonData['status'] == 'ok') {
        final List<dynamic> articles = jsonData['articles'];
        return articles.map((article) => Article.fromJson(article)).toList();
      } else {
        throw ApiException(jsonData['message'] ?? 'Failed to load articles');
      }
    } else if (response.statusCode == 401) {
      throw UnauthorizedException(
          'Invalid API key. Please check your API key.');
    } else if (response.statusCode == 429) {
      throw TooManyRequestsException(
          'Too many requests. Please try again later.');
    } else {
      throw ApiException(
          'Failed to load articles. Status code: ${response.statusCode}');
    }
  }

  // Close the HTTP client
  void dispose() {
    _client.close();
  }
}
