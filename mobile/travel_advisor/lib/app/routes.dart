import 'package:flutter/material.dart';

import '../features/analysis/screens/journey_analysis_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/intro_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/verify_account_screen.dart';
import '../features/chatbot/screens/chatbot_screen.dart';
import '../features/location/screens/location_permission_screen.dart';
import '../features/onboarding/screens/role_selection_screen.dart';
import '../features/trip/screens/trip_details_screen.dart';


class AppRoutes {
  static const String splash = '/';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';

  static const String forgotPassword =
      '/forgot-password';

  static const String resetPassword =
      '/reset-password';

  static const String verifyAccount =
      '/verify-account';

  static const String roleSelection =
      '/role-selection';

  static const String locationPermission =
      '/location-permission';

  static const String tripDetails =
      '/trip-details';

  static const String chatbot =
      '/chatbot';

  static const String journeyAnalysis =
      '/journey-analysis';


  static Map<String, WidgetBuilder> get routes => {
        splash: (context) =>
            const SplashScreen(),

        intro: (context) =>
            const IntroScreen(),

        login: (context) =>
            const LoginScreen(),

        signup: (context) =>
            const SignUpScreen(),

        otp: (context) =>
            const OtpScreen(),

        forgotPassword: (context) =>
            const ForgotPasswordScreen(),

        resetPassword: (context) =>
            const ResetPasswordScreen(),

        verifyAccount: (context) =>
            const VerifyAccountScreen(),

        roleSelection: (context) =>
            const RoleSelectionScreen(),

        locationPermission: (context) =>
            const LocationPermissionScreen(),

        tripDetails: (context) =>
            const TripDetailsScreen(),

        chatbot: (context) =>
            const ChatbotScreen(),

        journeyAnalysis: (context) =>
            const JourneyAnalysisScreen(),
      };
}