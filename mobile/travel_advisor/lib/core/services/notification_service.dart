import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

  /// Initialize local notifications, timezone registry, and notification channel
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}

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

  /// Schedule a daily commute alert using Android's system AlarmManager
  Future<bool> scheduleDailyCommuteAlert({
    int id = 1001,
    required TimeOfDay alertTime,
    required String title,
    required String body,
    int score = 70,
    List<String> warnings = const [],
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      await requestPermission();

      final now = DateTime.now();
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        alertTime.hour,
        alertTime.minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final tzLocation = tz.local;
      final tzScheduled = tz.TZDateTime(
        tzLocation,
        scheduled.year,
        scheduled.month,
        scheduled.day,
        alertTime.hour,
        alertTime.minute,
      );

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

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'commute_scheduled_alert',
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'commute_scheduled_alert',
        );
      }

      debugPrint('Scheduled daily alert #$id at ${alertTime.hour}:${alertTime.minute}');
      return true;
    } catch (e) {
      debugPrint('Failed to schedule daily commute alert: $e');
      return false;
    }
  }

  /// Cancel any active scheduled commute alerts
  Future<void> cancelScheduledAlert({int id = 1001}) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error canceling scheduled alert: $e');
    }
  }
}
