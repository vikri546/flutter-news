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

  // Available categories from API
  static const List<String> _availableCategories = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
    'NASIONAL',
    'INTERNASIONAL',
  ];

  // Initialize scheduler
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (notificationsEnabled) {
      await startPeriodicNotifications();
    }
  }

  // Request permission if needed
  Future<bool> requestPermissionIfNeeded() async {
    return await _notificationService.requestPermissionIfNeeded();
  }

  Future<bool> isPermissionGranted() async {
    return await areNotificationsEnabled();
  }

  // Get enabled categories from preferences
  Future<List<String>> getEnabledCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledCategories = <String>[];

    for (final category in _availableCategories) {
      final isEnabled = prefs.getBool('notif_category_$category') ?? false;
      if (isEnabled) {
        enabledCategories.add(category);
      }
    }

    // If no categories are enabled, return all categories
    if (enabledCategories.isEmpty) {
      return _availableCategories;
    }

    return enabledCategories;
  }

  // Update category preferences (called when user changes settings)
  Future<void> updateCategoryPreferences() async {
    // Restart periodic notifications to apply new preferences
    if (await areNotificationsEnabled()) {
      await stopPeriodicNotifications();
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

    // Send first notification after 1 minute (for testing)
    Timer(const Duration(minutes: 1), () async {
      await _sendPeriodicNotification();
    });
  }

  // Stop periodic notifications
  Future<void> stopPeriodicNotifications() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // Send periodic notification based on enabled categories
  Future<void> _sendPeriodicNotification() async {
    try {
      // Get enabled categories
      final enabledCategories = await getEnabledCategories();
      if (enabledCategories.isEmpty) return;

      // Pick a random category from enabled ones
      final selectedCategory =
          enabledCategories[_random.nextInt(enabledCategories.length)];

      // Get articles from selected category
      final articles = await _getArticlesByCategory(selectedCategory);
      if (articles.isEmpty) return;

      // Check if breaking news is enabled
      final prefs = await SharedPreferences.getInstance();
      final breakingNewsEnabled = prefs.getBool('notif_breaking_news') ?? true;
      final topBusinessEnabled = prefs.getBool('notif_top_business') ?? true;
      final topNewsEnabled = prefs.getBool('notif_top_news') ?? true;

      // Determine notification type based on settings and category
      if (breakingNewsEnabled &&
          (selectedCategory == 'NASIONAL' || selectedCategory == 'INTERNASIONAL')) {
        await _sendBreakingNewsNotification(articles, selectedCategory);
      } else if (topBusinessEnabled && selectedCategory == 'EKBIS') {
        await _sendTrendingNotification(articles, selectedCategory);
      } else if (topNewsEnabled) {
        await _sendRecommendationNotification(articles, selectedCategory);
      }
    } catch (e) {
      print('Error sending periodic notification: $e');
    }
  }

  // Get articles by specific category
  Future<List<Article>> _getArticlesByCategory(String category) async {
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        category,
        forceRefresh: true,
        page: 1,
        pageSize: 10,
      );

      // Shuffle and take first 3 articles
      articles.shuffle(_random);
      return articles.take(3).toList();
    } catch (e) {
      print('Error fetching articles for category $category: $e');
      return [];
    }
  }

  // Get trending articles (from all enabled categories)
  Future<List<Article>> _getTrendingArticles() async {
    try {
      final enabledCategories = await getEnabledCategories();
      if (enabledCategories.isEmpty) return [];

      // Pick a random category
      final category =
          enabledCategories[_random.nextInt(enabledCategories.length)];

      return await _getArticlesByCategory(category);
    } catch (e) {
      print('Error fetching trending articles: $e');
      return [];
    }
  }

  // Send trending notification with category info
  Future<void> _sendTrendingNotification(
      List<Article> articles, String category) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final categoryName = _getCategoryDisplayName(category);
    final title = 'Trending in $categoryName';
    final body = _truncateText(article.title, 100);

    await _notificationService.showTrendingNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send recommendation notification with category info
  Future<void> _sendRecommendationNotification(
      List<Article> articles, String category) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final categoryName = _getCategoryDisplayName(category);
    final title = 'New in $categoryName';
    final body = _truncateText(article.title, 100);

    await _notificationService.showRecommendationNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send breaking news notification with category info
  Future<void> _sendBreakingNewsNotification(
      List<Article> articles, String category) async {
    if (articles.isEmpty) return;

    final article = articles[_random.nextInt(articles.length)];
    final categoryName = _getCategoryDisplayName(category);
    final title = 'Breaking: $categoryName';
    final body = _truncateText(article.title, 100);

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Get display name for category
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'HYPE':
        return 'Hype';
      case 'OLAHRAGA':
        return 'Olahraga';
      case 'EKBIS':
        return 'Ekonomi & Bisnis';
      case 'MEGAPOLITAN':
        return 'Megapolitan';
      case 'DAERAH':
        return 'Daerah';
      case 'NASIONAL':
        return 'Nasional';
      case 'INTERNASIONAL':
        return 'Internasional';
      default:
        return category;
    }
  }

  // Truncate text to specified length
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Send immediate notification (for testing)
  Future<void> sendTestNotification() async {
    final enabledCategories = await getEnabledCategories();
    if (enabledCategories.isEmpty) return;

    final category =
        enabledCategories[_random.nextInt(enabledCategories.length)];
    final articles = await _getArticlesByCategory(category);

    if (articles.isNotEmpty) {
      await _sendTrendingNotification(articles, category);
    }
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await startPeriodicNotifications();
      await _backgroundService.initialize();
    } else {
      await stopPeriodicNotifications();
      await _backgroundService.stopBackgroundTask();
      await _notificationService.cancelAllNotifications();
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // Send notification for new article in specific category
  Future<void> sendNewArticleNotification(
      Article article, String category) async {
    if (!await areNotificationsEnabled()) return;

    // Check if category notification is enabled
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('notif_category_$category') ?? false;

    if (!categoryEnabled) return;

    final categoryName = _getCategoryDisplayName(category);
    final title = 'New Article in $categoryName';
    final body = _truncateText(article.title, 100);

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send notification for trending article in specific category
  Future<void> sendTrendingArticleNotification(
      Article article, String category) async {
    if (!await areNotificationsEnabled()) return;

    // Check if category notification is enabled
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('notif_category_$category') ?? false;

    if (!categoryEnabled) return;

    final categoryName = _getCategoryDisplayName(category);
    final title = 'Trending in $categoryName';
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