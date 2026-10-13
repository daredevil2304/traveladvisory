import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1100),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    _checkSession();
  }

  // ============================================================
  // SESSION CHECK
  // ============================================================

  Future<void> _checkSession() async {
    await Future.delayed(
      const Duration(milliseconds: 2600),
    );

    if (!mounted) {
      return;
    }

    try {
      final hasSession =
          await ApiService.hasStoredSession();

      if (!mounted) {
        return;
      }

      if (hasSession) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleSelection,
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.intro,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      // If the local session check fails,
      // safely fall back to the normal
      // first-time flow.
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.intro,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppTheme.deepGreen,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // TOP DECORATION
            // ==================================================

            Positioned(
              top: -100,
              right: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.teal
                      .withValues(alpha: 0.12),
                ),
              ),
            ),

            // ==================================================
            // BOTTOM DECORATION
            // ==================================================

            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.orange
                      .withValues(alpha: 0.07),
                ),
              ),
            ),

            // ==================================================
            // LOGO + TITLE
            // ==================================================

            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 36,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/mumbai_pune_travel_advisor_logo.svg',
                          width: 280,
                        ),

                        const SizedBox(
                          height: 30,
                        ),

                        const Text(
                          'Safer Roads.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),

                        const Text(
                          'Smarter Journeys.',
                          style: TextStyle(
                            color: AppTheme.mint,
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // FOOTER
            // ==================================================

            const Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Text(
                'TRAVEL INTELLIGENCE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}