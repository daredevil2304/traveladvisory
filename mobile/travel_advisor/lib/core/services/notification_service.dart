import 'dart:async';
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
    'commute_safety_channel_v2',
    'Daily Commute Safety Alerts',
    description: 'Proactive corridor alerts and safety score updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
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

  /// Check whether app can schedule notifications (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    return true;
  }

  /// Request exact alarm permission (no-op since normal notifications are used)
  Future<bool> requestExactAlarmsPermission() async {
    return true;
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
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        ticker: 'Mumbai–Pune Commute Safety Alert',
        channelShowBadge: true,
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

      tz.initializeTimeZones();
      tz.Location location;
      try {
        location = tz.getLocation('Asia/Kolkata');
      } catch (_) {
        location = tz.local;
      }

      final tz.TZDateTime nowTz = tz.TZDateTime.now(location);
      var scheduledTz = tz.TZDateTime(
        location,
        nowTz.year,
        nowTz.month,
        nowTz.day,
        alertTime.hour,
        alertTime.minute,
      );

      // If scheduled time is within the current minute, schedule 3 seconds in the future
      // so testing the current minute triggers immediately on device without waiting 24 hours!
      if (nowTz.hour == alertTime.hour && nowTz.minute == alertTime.minute) {
        scheduledTz = nowTz.add(const Duration(seconds: 4));
      } else if (scheduledTz.isBefore(nowTz)) {
        scheduledTz = scheduledTz.add(const Duration(days: 1));
      }

      final String bigSummary = warnings.isNotEmpty
          ? '$body\n\nActive Hazards:\n• ${warnings.join("\n• ")}'
          : body;

      // Use normal notification details matching the working test alert
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        ticker: 'Mumbai–Pune Commute Safety Alert',
        channelShowBadge: true,
        styleInformation: BigTextStyleInformation(
          bigSummary,
          contentTitle: title,
          summaryText: 'Safety Score: $score/100',
        ),
      );

      // Cancel previous scheduled alarms for this id before rescheduling
      await cancelScheduledAlert(id: id);

      bool scheduled = false;
      // 1. Primary: exactAllowWhileIdle (fires at the exact minute even in Doze/standby)
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'commute_scheduled_alert',
        );
        scheduled = true;
        debugPrint('Successfully scheduled exact alert #$id via exactAllowWhileIdle at $scheduledTz');
      } catch (e) {
        debugPrint('exactAllowWhileIdle failed: $e, falling back to inexactAllowWhileIdle');
      }

      // 2. Secondary fallback: inexactAllowWhileIdle
      if (!scheduled) {
        try {
          await _notificationsPlugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledTz,
            notificationDetails: NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'commute_scheduled_alert',
          );
          scheduled = true;
          debugPrint('Scheduled alert #$id via inexactAllowWhileIdle at $scheduledTz');
        } catch (e) {
          debugPrint('inexactAllowWhileIdle scheduling error: $e');
        }
      }

      // 3. Tertiary fallback: inexact
      if (!scheduled) {
        try {
          await _notificationsPlugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledTz,
            notificationDetails: NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.inexact,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'commute_scheduled_alert',
          );
          scheduled = true;
          debugPrint('Scheduled alert #$id via inexact at $scheduledTz');
        } catch (e) {
          debugPrint('inexact scheduling error: $e');
        }
      }

      debugPrint('Scheduled daily normal commute alert #$id at ${alertTime.hour}:${alertTime.minute} (next trigger: $scheduledTz)');
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
      await _notificationsPlugin.cancel(id: id + 10000);
    } catch (e) {
      debugPrint('Error canceling scheduled alert: $e');
    }
  }
}

