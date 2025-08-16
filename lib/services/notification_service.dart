import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Added for Color

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initializationSettings);

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;
  }

  Future<void> _createNotificationChannels() async {
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // Breaking News Channel - HIGHEST VOLUME
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'breaking_news',
          'Breaking News',
          description: 'Important breaking news notifications',
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
              'dtalk_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFFE74C3C),
        ),
      );

      // Trending Articles Channel - HIGH VOLUME
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'trending_articles',
          'Trending Articles',
          description: 'Trending and popular articles',
          importance: Importance.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
              'dtalk_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF3498DB),
        ),
      );

      // Recommendations Channel - MEDIUM VOLUME
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'recommendations',
          'Article Recommendations',
          description: 'Personalized article recommendations',
          importance: Importance.defaultImportance,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
              'dtalk_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF2ECC71),
        ),
      );
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('notif_perm_asked') ?? false;
    if (asked) return true;
    await prefs.setBool('notif_perm_asked', true);
    // On Android 13+, permission is handled by plugin's resolvePermission
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted =
          await androidImpl.requestNotificationsPermission() ?? true;
      return granted;
    }
    return true;
  }

  Future<void> showBreakingNewsNotification(String title, String body,
      {String? payload}) async {
    await init();
    final android = AndroidNotificationDetails(
      'breaking_news',
      'Breaking News',
      channelDescription: 'Important breaking news notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound:
          const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      color: const Color(0xFFE74C3C),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      chronometerCountDown: false,
      showProgress: false,
      maxProgress: 0,
      progress: 0,
      indeterminate: false,
      onlyAlertOnce: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
      ticker: 'Breaking News: $title',
    );
    final details = NotificationDetails(android: android);
    await _fln.show(
        DateTime.now().millisecondsSinceEpoch % 100000, title, body, details,
        payload: payload);
  }

  Future<void> showTrendingNotification(String title, String body,
      {String? payload}) async {
    await init();
    final android = AndroidNotificationDetails(
      'trending_articles',
      'Trending Articles',
      channelDescription: 'Trending and popular articles',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound:
          const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
      color: const Color(0xFF3498DB),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      chronometerCountDown: false,
      showProgress: false,
      maxProgress: 0,
      progress: 0,
      indeterminate: false,
      onlyAlertOnce: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
      ticker: 'Trending: $title',
    );
    final details = NotificationDetails(android: android);
    await _fln.show(DateTime.now().millisecondsSinceEpoch % 100000 + 1, title,
        body, details,
        payload: payload);
  }

  Future<void> showRecommendationNotification(String title, String body,
      {String? payload}) async {
    await init();
    final android = AndroidNotificationDetails(
      'recommendations',
      'Article Recommendations',
      channelDescription: 'Personalized article recommendations',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      sound:
          const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      color: const Color(0xFF2ECC71),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      chronometerCountDown: false,
      showProgress: false,
      maxProgress: 0,
      progress: 0,
      indeterminate: false,
      onlyAlertOnce: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
      ticker: 'Recommendation: $title',
    );
    final details = NotificationDetails(android: android);
    await _fln.show(DateTime.now().millisecondsSinceEpoch % 100000 + 2, title,
        body, details,
        payload: payload);
  }

  Future<void> showInstant(String title, String body, {String? payload}) async {
    await showRecommendationNotification(title, body, payload: payload);
  }

  Future<void> pruneOlderThanDays(int days) async {
    // Plugin does not store history; we can cancel all scheduled beyond retention if used; kept as placeholder.
  }

  // Get notification channels
  Future<List<AndroidNotificationChannel>> getNotificationChannels() async {
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.getNotificationChannels() ?? [];
    }
    return [];
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _fln.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _fln.cancel(id);
  }

  // Method to ensure maximum volume for notifications
  Future<void> ensureMaximumVolume() async {
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // Update existing channels with maximum importance
      final channels = await getNotificationChannels();
      for (final channel in channels) {
        await androidImpl.deleteNotificationChannel(channel.id);
      }

      // Recreate channels with maximum volume settings
      await _createNotificationChannels();
    }
  }

  // Method to test notification with maximum volume
  Future<void> testMaximumVolumeNotification() async {
    await ensureMaximumVolume();
    await showBreakingNewsNotification(
      'Test Volume',
      'This is a test notification with maximum volume settings',
    );
  }
}
