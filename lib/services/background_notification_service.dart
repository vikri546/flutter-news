import 'dart:async';
import 'dart:math';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import 'notification_service.dart';

class BackgroundNotificationService {
  static const String _taskName = 'backgroundNotificationTask';
  static const String _periodicTaskName = 'periodicNotificationTask';

  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();

  // Initialize background service
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    // Register periodic task for notifications
    await Workmanager().registerPeriodicTask(
      _periodicTaskName,
      _periodicTaskName,
      frequency: const Duration(hours: 4), // Every 4 hours
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  // Start background task
  Future<void> startBackgroundTask() async {
    await Workmanager().registerOneOffTask(
      _taskName,
      _taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  // Stop background task
  Future<void> stopBackgroundTask() async {
    await Workmanager().cancelAll();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await startBackgroundTask();
    } else {
      await stopBackgroundTask();
      await _notificationService.cancelAllNotifications();
    }
  }

  // Get last notification time
  Future<DateTime?> getLastNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_notification_time');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // Set last notification time
  Future<void> setLastNotificationTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_notification_time', time.millisecondsSinceEpoch);
  }

  // Check if enough time has passed since last notification
  Future<bool> shouldSendNotification() async {
    final lastTime = await getLastNotificationTime();
    if (lastTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastTime);

    // Don't send notification if less than 2 hours have passed
    return difference.inHours >= 2;
  }

  // Get trending articles for notifications
  Future<List<Article>> getTrendingArticles() async {
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        'All',
        forceRefresh: true,
        page: 1,
        pageSize: 10,
        country: 'us', // Default to US, can be made dynamic
      );

      // Shuffle and take first 3 articles
      final random = Random();
      articles.shuffle(random);
      return articles.take(3).toList();
    } catch (e) {
      print('Error fetching trending articles: $e');
      return [];
    }
  }

  // Send trending notification
  Future<void> sendTrendingNotification() async {
    if (!await areNotificationsEnabled()) return;
    if (!await shouldSendNotification()) return;

    final articles = await getTrendingArticles();
    if (articles.isEmpty) return;

    final random = Random();
    final article = articles[random.nextInt(articles.length)];

    final title = 'Trending Now';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showTrendingNotification(
      title,
      body,
      payload: article.url,
    );

    await setLastNotificationTime(DateTime.now());
  }

  // Send breaking news notification
  Future<void> sendBreakingNewsNotification(Article article) async {
    if (!await areNotificationsEnabled()) return;

    final title = 'Breaking News';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send recommendation notification
  Future<void> sendRecommendationNotification(Article article) async {
    if (!await areNotificationsEnabled()) return;
    if (!await shouldSendNotification()) return;

    final title = 'Recommended for You';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showRecommendationNotification(
      title,
      body,
      payload: article.url,
    );

    await setLastNotificationTime(DateTime.now());
  }
}

// Callback function for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final backgroundService = BackgroundNotificationService();

      switch (task) {
        case 'backgroundNotificationTask':
        case 'periodicNotificationTask':
          await backgroundService.sendTrendingNotification();
          break;
        default:
          print('Unknown task: $task');
      }

      return Future.value(true);
    } catch (e) {
      print('Background task error: $e');
      return Future.value(false);
    }
  });
}
