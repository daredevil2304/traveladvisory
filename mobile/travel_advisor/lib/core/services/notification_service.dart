import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'commute_safety_channel',
    'Daily Commute Safety Alerts',
    description: 'Proactive corridor alerts and safety score updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize local notifications and register channel
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      final androidImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(_channel);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Request runtime notification permission (Android 13+)
  Future<bool> requestPermission() async {
    try {
      final androidImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return false;
  }

  /// Show a real system notification in the notification shade
  Future<bool> showCommuteNotification({
    required String title,
    required String body,
    int score = 70,
    List<String> warnings = const [],
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      // Explicitly request permission if not yet prompted
      await requestPermission();

      final String bigSummary = warnings.isNotEmpty
          ? '$body\n\nActive Hazards:\n• ${warnings.join("\n• ")}'
          : body;

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Mumbai–Pune Commute Safety Alert',
        styleInformation: BigTextStyleInformation(
          bigSummary,
          contentTitle: title,
          summaryText: 'Safety Score: $score/100',
        ),
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: 'commute_alert',
      );

      return true;
    } catch (e) {
      debugPrint('Failed to send real system notification: $e');
      return false;
    }
  }
}
