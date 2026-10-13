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
                'Real-Time Insights\nfor a Smarter Journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkNavy,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Get the information you need,\nwhen you need it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
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
                      subtitle: 'Live alerts',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.route_outlined,
                      title: 'Route Risk',
                      subtitle: 'Smart analysis',
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
                      title: 'Reports',
                      subtitle: 'Traveler insights',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.shield_outlined,
                      title: 'Safety',
                      subtitle: 'Recommendations',
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