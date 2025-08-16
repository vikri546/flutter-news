import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import 'notification_service.dart';
import 'background_notification_service.dart';

class NotificationScheduler {
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final BackgroundNotificationService _backgroundService =
      BackgroundNotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();

  Timer? _periodicTimer;
  final Random _random = Random();

  // Initialize scheduler
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (notificationsEnabled) {
      await startPeriodicNotifications();
    }
  }

  // Start periodic notifications
  Future<void> startPeriodicNotifications() async {
    // Cancel existing timer if any
    _periodicTimer?.cancel();

    // Schedule notifications every 4 hours
    _periodicTimer = Timer.periodic(const Duration(hours: 4), (timer) async {
      await _sendPeriodicNotification();
    });
  }

  // Stop periodic notifications
  Future<void> stopPeriodicNotifications() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // Send periodic notification
  Future<void> _sendPeriodicNotification() async {
    try {
      // Get trending articles
      final articles = await _getTrendingArticles();
      if (articles.isEmpty) return;

      // Randomly select notification type
      final notificationTypes = [
        _sendTrendingNotification,
        _sendRecommendationNotification,
        _sendBreakingNewsNotification,
      ];

      final selectedType =
          notificationTypes[_random.nextInt(notificationTypes.length)];
      await selectedType(articles);
    } catch (e) {
      print('Error sending periodic notification: $e');
    }
  }

  // Get trending articles
  Future<List<Article>> _getTrendingArticles() async {
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        'All',
        forceRefresh: true,
        page: 1,
        pageSize: 10,
        country: 'us',
      );

      // Shuffle and take first 3 articles
      articles.shuffle(_random);
      return articles.take(3).toList();
    } catch (e) {
      print('Error fetching trending articles: $e');
      return [];
    }
  }

  // Send trending notification
  Future<void> _sendTrendingNotification(List<Article> articles) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final title = 'Trending Now';
    final body = _truncateText(article.title, 100);

    await _notificationService.showTrendingNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send recommendation notification
  Future<void> _sendRecommendationNotification(List<Article> articles) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final title = 'Recommended for You';
    final body = _truncateText(article.title, 100);

    await _notificationService.showRecommendationNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send breaking news notification
  Future<void> _sendBreakingNewsNotification(List<Article> articles) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final title = 'Breaking News';
    final body = _truncateText(article.title, 100);

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Truncate text to specified length
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Send immediate notification (for testing)
  Future<void> sendTestNotification() async {
    final articles = await _getTrendingArticles();
    if (articles.isNotEmpty) {
      await _sendTrendingNotification(articles);
    }
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await startPeriodicNotifications();
    } else {
      await stopPeriodicNotifications();
      await _notificationService.cancelAllNotifications();
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // Send notification for new article
  Future<void> sendNewArticleNotification(Article article) async {
    if (!await areNotificationsEnabled()) return;

    final title = 'New Article';
    final body = _truncateText(article.title, 100);

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send notification for trending article
  Future<void> sendTrendingArticleNotification(Article article) async {
    if (!await areNotificationsEnabled()) return;

    final title = 'Trending';
    final body = _truncateText(article.title, 100);

    await _notificationService.showTrendingNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Dispose resources
  void dispose() {
    _periodicTimer?.cancel();
  }
}
