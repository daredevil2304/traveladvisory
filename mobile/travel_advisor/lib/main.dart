import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/services/commute_habit_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/shorebird_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize habit detection and proactive commute alert schedule
  try {
    CommuteHabitService().init();
  } catch (e) {
    debugPrint('Commute habit service initialization error: $e');
  }

  // Initialize real notifications and register system channel
  try {
    await NotificationService().init();
    NotificationService().requestPermission();
  } catch (e) {
    debugPrint('Notification service initialization error: $e');
  }

  // Initialize Shorebird Over-The-Air code push service
  try {
    ShorebirdService().init();
  } catch (e) {
    debugPrint('Shorebird initialization error: $e');
  }

  runApp(const TravelAdvisorApp());
}