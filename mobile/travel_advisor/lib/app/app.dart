import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';

class TravelAdvisorApp extends StatelessWidget {
  const TravelAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Based Travel Advisory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}