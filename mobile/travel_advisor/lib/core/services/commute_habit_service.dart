import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class CommuteHabitService {
  static final CommuteHabitService _instance = CommuteHabitService._internal();
  factory CommuteHabitService() => _instance;
  CommuteHabitService._internal();

  final ValueNotifier<Map<String, dynamic>?> activeAlertNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  final ValueNotifier<Map<String, dynamic>?> commuteHabitNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  final ValueNotifier<bool> hasUnreadAlertNotifier =
      ValueNotifier<bool>(false);

  final ValueNotifier<bool> isLoadingNotifier =
      ValueNotifier<bool>(false);

  Timer? _scheduleTimer;
  bool _initialized = false;

  /// Initialize service and check for active commute alerts
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await loadHabit();
    await checkCommuteAlertWindow();

    // Check every 5 minutes while the app is alive
    _scheduleTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      checkCommuteAlertWindow();
    });
  }

  void dispose() {
    _scheduleTimer?.cancel();
  }

  /// Load learned commute habit
  Future<Map<String, dynamic>?> loadHabit() async {
    try {
      final res = await ApiService.getCommuteHabit();
      if (res['habit'] != null) {
        final habitData = Map<String, dynamic>.from(res['habit']);
        commuteHabitNotifier.value = habitData;
        return habitData;
      }
    } catch (_) {
      // Offline fallback
    }
    return commuteHabitNotifier.value;
  }

  /// Save / customize commute habit
  Future<bool> saveHabit({
    required String source,
    required String destination,
    required String departureTime,
    required String alertTime,
    String? travelDays,
    bool isEnabled = true,
  }) async {
    isLoadingNotifier.value = true;
    try {
      final res = await ApiService.saveCommuteHabit(
        source: source,
        destination: destination,
        departureTime: departureTime,
        alertTime: alertTime,
        travelDays: travelDays,
        isEnabled: isEnabled,
      );
      if (res['habit'] != null) {
        commuteHabitNotifier.value = Map<String, dynamic>.from(res['habit']);
      }
      isLoadingNotifier.value = false;
      return true;
    } catch (_) {
      isLoadingNotifier.value = false;
      return false;
    }
  }

  /// Log every time the user checks a trip to continuously learn habits
  Future<void> logCheck({
    required String source,
    required String destination,
    String? departureTime,
  }) async {
    try {
      final now = DateTime.now();
      final String hour = now.hour.toString().padLeft(2, '0');
      final String min = now.minute.toString().padLeft(2, '0');
      final String checkTime = '$hour:$min';

      await ApiService.logCommuteCheck(
        source: source,
        destination: destination,
        departureTime: departureTime,
        checkTime: checkTime,
      );

      // Reload updated habit in background
      unawaited(loadHabit());
    } catch (_) {
      // Fire-and-forget
    }
  }

  /// Check whether current time matches the alert time window
  Future<void> checkCommuteAlertWindow() async {
    final habit = commuteHabitNotifier.value ?? await loadHabit();
    if (habit == null || habit['is_enabled'] != true) {
      return;
    }

    final String alertTimeStr = habit['alert_time'] ?? '07:45';
    final now = DateTime.now();
    final parts = alertTimeStr.split(':');
    if (parts.length < 2) return;

    final int targetHour = int.tryParse(parts[0]) ?? 7;
    final int targetMinute = int.tryParse(parts[1]) ?? 45;

    // Trigger alert if current time is within 30 minutes following the alert time
    final targetMinutesSinceMidnight = targetHour * 60 + targetMinute;
    final currentMinutesSinceMidnight = now.hour * 60 + now.minute;

    final diff = currentMinutesSinceMidnight - targetMinutesSinceMidnight;
    if (diff >= -5 && diff <= 45) {
      if (activeAlertNotifier.value == null) {
        await fetchAlert(
          source: habit['source'] ?? 'Panvel',
          destination: habit['destination'] ?? 'Pune',
        );
      }
    }
  }

  /// Fetch live corridor assessment for the commute
  Future<Map<String, dynamic>?> fetchAlert({
    String source = 'Panvel',
    String destination = 'Pune',
  }) async {
    isLoadingNotifier.value = true;
    try {
      final res = await ApiService.getCommuteAlert(
        source: source,
        destination: destination,
      );

      if (res['alert'] != null) {
        final alertData = Map<String, dynamic>.from(res['alert']);
        activeAlertNotifier.value = alertData;
        hasUnreadAlertNotifier.value = true;
        isLoadingNotifier.value = false;
        return alertData;
      }
    } catch (_) {
      // Silent error handling
    }
    isLoadingNotifier.value = false;
    return null;
  }

  /// Dismiss the active alert banner
  void dismissAlert() {
    activeAlertNotifier.value = null;
    hasUnreadAlertNotifier.value = false;
  }

  /// Manually trigger a test notification alert for verification
  Future<Map<String, dynamic>?> triggerTestAlert() async {
    final habit = commuteHabitNotifier.value ?? await loadHabit();
    final src = habit?['source'] ?? 'Panvel';
    final dst = habit?['destination'] ?? 'Pune';
    return await fetchAlert(source: src, destination: dst);
  }
}
