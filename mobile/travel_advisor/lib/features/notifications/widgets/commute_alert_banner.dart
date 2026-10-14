import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/commute_habit_service.dart';

class CommuteAlertBanner extends StatelessWidget {
  const CommuteAlertBanner({super.key});

  Color _getScoreColor(int score) {
    if (score < 40) return AppTheme.crimsonRed;
    if (score < 60) return AppTheme.alertAmber;
    if (score < 75) return const Color(0xFFF59E0B);
    return AppTheme.forestGreen;
  }

  @override
  Widget build(BuildContext context) {
    final habitService = CommuteHabitService();

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: habitService.activeAlertNotifier,
      builder: (context, alert, child) {
        if (alert == null) {
          return const SizedBox.shrink();
        }

        final int score = (alert['safety_score'] as num?)?.toInt() ?? 70;
        final String riskLevel = alert['risk_level'] ?? 'Moderate';
        final Color scoreColor = _getScoreColor(score);
        final String src = alert['source'] ?? 'Panvel';
        final String dst = alert['destination'] ?? 'Pune';
        final String body = alert['alert_body'] ?? '';
        final List warnings = (alert['warnings'] as List?) ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scoreColor.withOpacity(0.12),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: scoreColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top title bar
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 8, top: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scoreColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Score $score/100 • $riskLevel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$src ➔ $dst Alert',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      tooltip: 'Dismiss Alert',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => habitService.dismissAlert(),
                    ),
                  ],
                ),
              ),

              // Body summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Horizontal hazard pills if any
              if (warnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: warnings.take(3).map((w) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: scoreColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            w.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Action buttons
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Automated Pre-Trip Notification',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.forestGreen,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text(
                        'View Warnings',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.commuteAlerts);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
