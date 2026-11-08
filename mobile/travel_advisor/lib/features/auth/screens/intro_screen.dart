import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';


class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            24,
          ),
          child: Column(
            children: [
              const Spacer(),

              SvgPicture.asset(
                'assets/images/mumbai_pune_travel_advisor_logo.svg',
                width: 250,
              ),

              const SizedBox(height: 42),

              const Text(
                'Safe & Smart Travel on\nMumbai–Pune Expressway',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkNavy,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Check live road traffic, rain, fog, and\nsafe driving speeds before you drive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 34),

              Row(
                children: const [
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.cloud_outlined,
                      title: 'Weather',
                      subtitle: 'Rain & fog alerts',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.route_outlined,
                      title: 'Road Safety',
                      subtitle: 'Easy safety score',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: const [
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.groups_outlined,
                      title: 'Driver Reports',
                      subtitle: 'Live road updates',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.shield_outlined,
                      title: 'Safe Speeds',
                      subtitle: 'Helpful driving tips',
                    ),
                  ),
                ],
              ),

              const Spacer(),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.login,
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('GET STARTED'),
              ),

              const SizedBox(height: 14),

              const Text(
                'Smarter Travel. Safer Tomorrows.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: AppTheme.forestGreen,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}