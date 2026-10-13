import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class JourneyAnalysisScreen extends StatelessWidget {
  const JourneyAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    String source = 'Current Location';
    String destination = 'Destination';
    Map<String, dynamic> analysis = {};

    if (arguments is Map<String, dynamic>) {
      source = arguments['source'] ?? source;
      destination = arguments['destination'] ?? destination;
      if (arguments['analysis'] != null) {
        analysis = Map<String, dynamic>.from(arguments['analysis'] as Map);
      }
    }

    final overallScore = analysis['overall_safety_score'];
    final int score = (overallScore != null) ? (overallScore as num).toInt() : 0;
    
    final problematicSegmentsRaw = analysis['problematic_segments'];
    final List<dynamic> problematicSegments = (problematicSegmentsRaw is List) ? problematicSegmentsRaw : [];

    final segmentResultsRaw = analysis['segment_results'];
    final List<dynamic> segmentResults = (segmentResultsRaw is List) ? segmentResultsRaw : [];

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkNavy),
          onPressed: () {
            Navigator.pop(context); // Goes back to the chat (Change 6)
          },
        ),
        title: const Text(
          'Journey Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // HEADER
              Text(
                '$source to $destination',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // CIRCULAR METER (Change 3)
              SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: SafetyMeterPainter(score: score),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: _getScoreColor(score),
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          'Safety Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // PROBLEMATIC REGIONS (Change 4 & 5)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Regions to Watch Out For',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (problematicSegments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.lightMint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.forestGreen, size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'All regions on your route look perfectly safe! Enjoy your journey.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.forestGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...problematicSegments.map((segment) {
                  return _buildProblematicRegionCard(segment);
                }),

              if (segmentResults.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Corridor Segments Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...segmentResults.map((segment) {
                  return _buildSegmentCard(segment);
                }),
              ],

              const SizedBox(height: 40),

              // BOTTOM BUTTON (Change 6)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Takes them back to the chat to give inputs
                  },
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text(
                    'Share Live Updates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblematicRegionCard(dynamic segment) {
    if (segment is! Map) return const SizedBox.shrink();

    final details = segment['segment_details'];
    String title = segment['region'] ?? 'Unknown Region';

    if (details is Map && details['start'] != null && details['end'] != null) {
      title = 'Between ${details['start']} and ${details['end']}';
    }

    final dynamic rawScore = segment['safety_score'];
    final int? score = (rawScore != null) ? (rawScore as num).toInt() : null;
    final reasonsRaw = segment['reasons'];
    final List<dynamic> reasons = (reasonsRaw is List) ? reasonsRaw : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: $score',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...reasons.map((reason) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        reason.toString(),
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentCard(dynamic segment) {
    if (segment is! Map) return const SizedBox.shrink();

    final details = segment['segment_details'];
    String title = segment['region'] ?? 'Corridor Segment';

    if (details is Map && details['start'] != null && details['end'] != null) {
      title = '${details['start']} to ${details['end']}';
    }

    final safetyResult = segment['safety_score_result'];
    final dynamic rawScore = (safetyResult is Map) ? safetyResult['score'] : null;
    final int? score = (rawScore != null) ? (rawScore as num).toInt() : null;

    final weather = segment['weather_result'];
    String weatherSummary = 'Clear';
    if (weather is Map) {
      final cond = weather['weather_condition']?.toString() ?? 'Clear';
      final temp = weather['temperature_c'];
      if (temp != null) {
        weatherSummary = '$cond • ${temp is num ? temp.round() : temp}°C';
      } else {
        weatherSummary = cond;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightMint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alt_route_rounded, color: AppTheme.forestGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  weatherSummary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getScoreColor(score).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _getScoreColor(score),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.forestGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class SafetyMeterPainter extends CustomPainter {
  final int score;

  SafetyMeterPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width / 2, size.height / 2);
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double strokeWidth = 24.0;

    // Draw background track
    final Paint trackPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    
    // We draw a 240 degree arc (4.18879 radians), starting at 150 degrees (2.61799 radians)
    const double startAngle = 2.61799;
    const double sweepAngle = 4.18879;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // Calculate score sweep
    final double normalizedScore = (score / 100.0).clamp(0.0, 1.0);
    final double scoreSweepAngle = sweepAngle * normalizedScore;

    if (scoreSweepAngle > 0) {
      // Define the gradient
      const SweepGradient gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          Colors.red,
          Colors.orange,
          Colors.green,
        ],
        stops: [0.2, 0.6, 1.0],
      );

      final Paint scorePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, scoreSweepAngle, false, scorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SafetyMeterPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}