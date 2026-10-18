import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';

class JourneyAnalysisScreen extends StatefulWidget {
  const JourneyAnalysisScreen({super.key});

  @override
  State<JourneyAnalysisScreen> createState() => _JourneyAnalysisScreenState();
}

class _JourneyAnalysisScreenState extends State<JourneyAnalysisScreen> {
  bool _showAllDetails = false;
  bool _isSavingReport = false;
  bool _reportSaved = false;

  static const Map<String, String> _corridorSegmentMap = {
    'R1': 'Mumbai to Panvel',
    'R2': 'Panvel to Khalapur',
    'R3': 'Khalapur to Khopoli',
    'R4': 'Khopoli to Khandala (Bhor Ghat)',
    'R5': 'Khandala to Lonavala',
    'R6': 'Lonavala to Kamshet',
    'R7': 'Kamshet to Pune',
    'R8': 'Pune Urban Corridor',
  };

  String _resolveSegmentTitle(dynamic segment, {bool betweenPrefix = false}) {
    if (segment is! Map) return 'Corridor Segment';
    final details = segment['segment_details'];
    if (details is Map && details['start'] != null && details['end'] != null) {
      if (betweenPrefix) {
        return 'Between ${details['start']} and ${details['end']}';
      }
      return '${details['start']} → ${details['end']}';
    }
    final rawRegion = segment['region']?.toString().trim().toUpperCase() ?? '';
    if (_corridorSegmentMap.containsKey(rawRegion)) {
      final mapped = _corridorSegmentMap[rawRegion]!;
      if (betweenPrefix) {
        return 'Between $mapped';
      }
      return mapped;
    }
    return segment['region']?.toString() ?? 'Corridor Segment';
  }

  Future<void> _handleSaveReport(int? tripId, String source, String destination) async {
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID not available to save report.')),
      );
      return;
    }

    setState(() => _isSavingReport = true);
    try {
      final userId = (await ApiService.getStoredUserId()) ?? 1;
      await ApiService.saveReport(
        userId: userId,
        tripId: tripId,
        title: '$source → $destination Travel Report',
      );
      if (!mounted) return;
      setState(() {
        _reportSaved = true;
        _isSavingReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Travel report saved successfully.'),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: AppTheme.white,
            onPressed: () {
              if (mounted) {
                Navigator.pushNamed(context, AppRoutes.savedReports);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSavingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    String source = 'Current Location';
    String destination = 'Destination';
    String role = 'traveler';
    Map<String, dynamic> analysis = {};
    int? tripId;

    if (arguments is Map<String, dynamic>) {
      source = arguments['source'] ?? source;
      destination = arguments['destination'] ?? destination;
      role = (arguments['role']?.toString().toLowerCase() ?? 'traveler');
      if (arguments['analysis'] != null) {
        analysis = Map<String, dynamic>.from(arguments['analysis'] as Map);
      }
      if (arguments['tripId'] != null) {
        tripId = int.tryParse(arguments['tripId'].toString());
      } else if (analysis['trip_id'] != null) {
        tripId = int.tryParse(analysis['trip_id'].toString());
      }
    }

    final bool isPlanner = (role == 'planner');

    final overallScore = analysis['overall_safety_score'];
    final int score = (overallScore != null) ? (overallScore as num).toInt() : 0;

    final problematicSegmentsRaw = analysis['problematic_segments'];
    final List<dynamic> rawProblematic =
        (problematicSegmentsRaw is List) ? problematicSegmentsRaw : [];

    // Filter out safe segments (>= 85) that have normal fluid conditions
    final List<dynamic> problematicSegments = rawProblematic.where((segment) {
      if (segment is! Map) return false;
      final rawScore = segment['safety_score'];
      final double scoreVal = (rawScore is num) ? rawScore.toDouble() : 100.0;
      final rawReasons = segment['reasons'];
      final List<dynamic> reasons = (rawReasons is List) ? rawReasons : [];
      final hasRealHazard = reasons.any((r) {
        final str = r.toString().toLowerCase();
        return !str.contains('clear route') &&
            !str.contains('optimal fluid') &&
            !str.contains('xgboost') &&
            !str.contains('historical ml') &&
            !str.contains('no delays reported') &&
            !str.contains('advance planning mode');
      });
      return scoreVal < 85.0 || hasRealHazard;
    }).toList();

    final segmentResultsRaw = analysis['segment_results'];
    final List<dynamic> segmentResults =
        (segmentResultsRaw is List) ? segmentResultsRaw : [];

    final travelDate = analysis['travel_date']?.toString();
    final travelTime = analysis['travel_time']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkNavy),
          onPressed: () {
            Navigator.pop(context);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.darkNavy),
            tooltip: 'Saved Reports',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.savedReports);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ROUTE TITLE
              Text(
                '$source to $destination',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // LIVE ROAD UPDATES COMMUNITY FEED PILL
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.forestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.forestGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.campaign_outlined, size: 16, color: AppTheme.forestGreen),
                      SizedBox(width: 6),
                      Text(
                        'Live Road Updates Feed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.forestGreen),
                    ],
                  ),
                ),
              ),

              if (isPlanner && (travelDate != null || travelTime != null)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.lightMint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_note_rounded, size: 16, color: AppTheme.forestGreen),
                      const SizedBox(width: 6),
                      Text(
                        'Scheduled: ${travelDate ?? ''} ${travelTime ?? ''}'.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // CIRCULAR SAFETY METER GAUGE
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
                        const SizedBox(height: 4),
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

              const SizedBox(height: 36),

              // PROBLEMATIC REGIONS SECTION
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
              const SizedBox(height: 14),

              if (problematicSegments.isEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: AppTheme.lightMint,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 5,
                            color: const Color(0xFF16A34A),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppTheme.forestGreen, size: 28),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'All regions along your corridor appear secure with no major hazards.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.forestGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...problematicSegments.map((segment) {
                  return _buildProblematicRegionCard(segment);
                }),

              // CORRIDOR SEGMENTS SECTION
              if (segmentResults.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isPlanner ? 'Corridor Segments' : 'Route Overview',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ),
                    if (!isPlanner)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAllDetails = !_showAllDetails;
                          });
                        },
                        child: Text(
                          _showAllDetails ? 'Summary' : 'Full Details',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.forestGreen,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // For traveler: compact format by default unless expanded
                if (!isPlanner && !_showAllDetails)
                  _buildTravelerCompactOverview(segmentResults)
                else
                  // For planner (or expanded traveler): full deep breakdown
                  ...segmentResults.map((segment) {
                    return _buildSegmentCard(segment);
                  }),
              ],

              const SizedBox(height: 36),

              // SAVE REPORT BUTTON (On report analysis page)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: (_isSavingReport || _reportSaved)
                      ? null
                      : () => _handleSaveReport(tripId, source, destination),
                  icon: _isSavingReport
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.white,
                          ),
                        )
                      : Icon(
                          _reportSaved
                              ? Icons.check_circle_rounded
                              : Icons.bookmark_add_rounded,
                        ),
                  label: Text(
                    _isSavingReport
                        ? 'Saving Report...'
                        : _reportSaved
                            ? 'Report Saved'
                            : 'Save Report',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forestGreen,
                    foregroundColor: AppTheme.white,
                    disabledBackgroundColor: _reportSaved
                        ? AppTheme.forestGreen.withValues(alpha: 0.7)
                        : Colors.grey.shade300,
                    disabledForegroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // BOTTOM ACTION BUTTON (Live updates / Return to Chat)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      isPlanner
                          ? {'action': 'back_to_chat'}
                          : {'action': 'live_updates'},
                    );
                  },
                  icon: Icon(
                    isPlanner
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.add_location_alt_rounded,
                    color: AppTheme.royalCobalt,
                  ),
                  label: Text(
                    isPlanner ? 'Back to Chat' : 'Share Live Updates',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.royalCobalt,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppTheme.royalCobalt,
                      width: 1.5,
                    ),
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

  Widget _buildTravelerCompactOverview(List<dynamic> segments) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: List.generate(segments.length, (index) {
          final segment = segments[index];
          if (segment is! Map) return const SizedBox.shrink();

          final String title = _resolveSegmentTitle(segment);

          final safetyResult = segment['safety_score_result'];
          final dynamic rawScore = (safetyResult is Map)
              ? (safetyResult['safety_score'] ?? safetyResult['score'])
              : segment['safety_score'];
          final int score = (rawScore != null) ? (rawScore as num).toInt() : 80;
          final Color scoreColor = _getScoreColor(score);

          final weather = segment['weather_result'];
          String condText = 'Clear';
          if (weather is Map) {
            final cond = weather['weather_condition']?.toString() ?? 'Clear';
            final temp = weather['temperature_c'];
            if (temp != null) {
              condText = '$cond • ${temp is num ? temp.round() : temp}°C';
            } else {
              condText = cond;
            }
          }

          final liveTraffic = segment['live_traffic'];
          String trafficText = '';
          if (liveTraffic is Map && liveTraffic['status_label'] != null) {
            final delay = liveTraffic['delay_minutes'] ?? 0;
            if (delay > 0) {
              trafficText = ' • +${delay}m delay';
            } else {
              trafficText = ' • Free Flow';
            }
          }

          final bool isLast = index == segments.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast ? BorderSide.none : const BorderSide(color: AppTheme.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scoreColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  score >= 80 ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: scoreColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$condText$trafficText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _resolveRegionCode(dynamic segment) {
    if (segment is! Map) return '';
    final code = segment['region_code']?.toString().toUpperCase() ?? '';
    if (code.isNotEmpty) return code;
    final reg = segment['region']?.toString().toUpperCase() ?? '';
    if (reg.startsWith('R') && reg.length <= 3) return reg;
    for (final entry in _corridorSegmentMap.entries) {
      if (reg.contains(entry.key) || entry.value.toUpperCase() == reg) {
        return entry.key;
      }
    }
    return '';
  }

  String _getSectorSubtitle(String code) {
    switch (code) {
      case 'R1':
        return 'Urban Expressway Corridor';
      case 'R2':
        return 'Multi-Lane Plain Expressway';
      case 'R3':
        return 'Ghat Foothills & Approach Sector';
      case 'R4':
        return 'Bhor Ghat Mountain Pass & Hairpin Incline';
      case 'R5':
        return 'Khandala-Lonavala Crest & Plateau Zone';
      case 'R6':
        return 'Sahyadri Descending Plateau Sector';
      case 'R7':
        return 'Pune Metropolitan Approach Corridor';
      case 'R8':
        return 'Pune Bypass & Urban Arterial';
      default:
        return 'Corridor Transit Sector';
    }
  }

  String _getSectorAdvisory(String code, {bool isRain = false}) {
    String base;
    switch (code) {
      case 'R1':
        base = 'High-density urban commuter flow with frequent flyovers. Maintain safe following buffer and anticipate sudden lane merges near Vashi and CBD Belapur.';
        break;
      case 'R2':
        base = 'Open 6-lane high-speed expressway plain. Optimal fluid cruising sector; maintain designated fast-lane discipline and avoid sudden overtaking.';
        break;
      case 'R3':
        base = 'Ghat foothill approach. Heavy commercial trucks decelerate into lower gears; watch for slow-moving freight in the left lanes.';
        break;
      case 'R4':
        base = 'Steep Bhor Ghat mountain incline & hairpins. Maintain low-gear engine braking on downslopes, leave 40m+ clearance behind heavy trucks, and never overtake on blind curves.';
        break;
      case 'R5':
        base = 'High-altitude mountain crest transition. Watch for viaduct crosswinds, tunnel speed shifts, and toll queue merges near Lonavala.';
        break;
      case 'R6':
        base = 'Smooth descending plateau corridor. Optimal cruising visibility; be cautious of occasional slow utility vehicles near rural expressway exits.';
        break;
      case 'R7':
        base = 'Approaching Pune metropolitan expressway end. Traffic density increases near Somatne and Ravet; prepare for speed moderation and toll plazas.';
        break;
      case 'R8':
        base = 'Pune metropolitan arterial highway. Moderate urban speeds and expect multiple vehicle merges at city junctions.';
        break;
      default:
        base = 'Standard expressway transit sector. Maintain designated lane discipline and recommended cruising speed.';
    }

    if (isRain) {
      base += ' [WET SURFACE ADVISORY: Reduced pavement grip. Reduce cruising speed by 15-20 km/h and double braking distance.]';
    }
    return base;
  }

  Widget _buildProblematicRegionCard(dynamic segment) {
    if (segment is! Map) return const SizedBox.shrink();

    final String title = _resolveSegmentTitle(segment, betweenPrefix: true);
    final String regCode = _resolveRegionCode(segment);

    final dynamic rawScore = segment['safety_score'];
    final int? score = (rawScore != null) ? (rawScore as num).toInt() : null;
    final Color scoreColor = _getScoreColor(score ?? 50);
    final reasonsRaw = segment['reasons'];
    final List<dynamic> rawReasons = (reasonsRaw is List) ? reasonsRaw : [];

    // Filter strictly for real hazard factors (never positive or ML diagnostic strings)
    final List<String> reasons = rawReasons
        .map((r) => r.toString())
        .where((r) {
          final s = r.toLowerCase();
          return !s.contains('clear route') &&
              !s.contains('optimal fluid') &&
              !s.contains('xgboost') &&
              !s.contains('historical ml') &&
              !s.contains('no delays reported') &&
              !s.contains('advance planning mode');
        })
        .toList();

    if (reasons.isEmpty && score != null && score < 85) {
      reasons.add('Reduced safety margin on this stretch ($score/100). Exercise caution.');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: scoreColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (regCode.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                regCode,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ],
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
                                color: scoreColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Score: $score',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...reasons.map((reason) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, right: 6),
                                  child: Icon(Icons.warning_amber_rounded, size: 14, color: scoreColor),
                                ),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentCard(dynamic segment) {
    if (segment is! Map) return const SizedBox.shrink();

    final String title = _resolveSegmentTitle(segment);
    final String regCode = _resolveRegionCode(segment);
    final String sectorSubtitle = _getSectorSubtitle(regCode);

    final safetyResult = segment['safety_score_result'];
    final dynamic rawScore = (safetyResult is Map)
        ? (safetyResult['safety_score'] ?? safetyResult['score'])
        : segment['safety_score'];
    final int? score = (rawScore != null) ? (rawScore as num).toInt() : null;
    final Color scoreColor = _getScoreColor(score ?? 80);

    // Weather Telemetry
    final weather = segment['weather_result'];
    String cond = 'Clear';
    String tempStr = '--';
    String humidityStr = 'Dry Surface';
    bool isRain = false;
    if (weather is Map) {
      cond = weather['weather_condition']?.toString() ?? 'Clear';
      final temp = weather['temperature_c'];
      if (temp != null) {
        tempStr = '${temp is num ? temp.round() : temp}°C';
      }
      final rh = weather['relative_humidity'] ?? weather['humidity'];
      final rainVal = weather['rainfall_mm'] ?? weather['rain'];
      isRain = rainVal != null && rainVal.toString().toLowerCase() != 'no rain' && rainVal.toString() != '0';
      if (isRain) {
        humidityStr = 'Wet Pavement';
      } else if (rh != null) {
        humidityStr = '$rh% Humidity • Dry';
      }
    }

    // Traffic Telemetry
    final liveTraffic = segment['live_traffic'];
    String speedText = '85-100 km/h';
    String trafficState = 'Fluid Flow (No Delay)';
    Color trafficColor = const Color(0xFF16A34A);
    if (liveTraffic is Map && liveTraffic['status_label'] != null) {
      final delay = liveTraffic['delay_minutes'] ?? 0;
      final speed = liveTraffic['speed_advice']?.toString() ?? '';
      if (speed.isNotEmpty) speedText = speed;
      if (delay > 0) {
        trafficState = '+$delay min delay';
        trafficColor = const Color(0xFFD97706);
      } else {
        trafficState = 'Free Flowing (+0m delay)';
      }
    }

    // Risk factors / alerts (if any)
    final riskFactorsRaw = segment['risk_factors'] ?? (safetyResult is Map ? safetyResult['risk_factors'] : null);
    final List<dynamic> risksList = (riskFactorsRaw is List) ? riskFactorsRaw : [];
    final cleanRisks = risksList
        .map((r) => r.toString())
        .where((r) {
          final s = r.toLowerCase();
          return !s.contains('clear route') &&
              !s.contains('optimal fluid') &&
              !s.contains('xgboost') &&
              !s.contains('historical ml') &&
              !s.contains('no delays reported') &&
              !s.contains('advance planning mode');
        })
        .toList();

    final sectorAdvisory = _getSectorAdvisory(regCode, isRain: isRain);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: scoreColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (regCode.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                regCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sectorSubtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
                                color: scoreColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$score/100',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Telemetry Strip (Atmospheric & Transit)
                      Row(
                        children: [
                          // Atmosphere Tile
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isRain ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                                    size: 18,
                                    color: isRain ? AppTheme.royalCobalt : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$cond • $tempStr',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.darkNavy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          humidityStr,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppTheme.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Transit Speed Tile
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.speed_rounded,
                                    size: 18,
                                    color: trafficColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          speedText,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.darkNavy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          trafficState,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: trafficColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Sector Driving Advisory Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.forestGreen.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.forestGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.navigation_rounded,
                                  size: 14,
                                  color: AppTheme.forestGreen,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Sector Driving Advisory',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.forestGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sectorAdvisory,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppTheme.darkNavy.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Active Hazards Warning (if any)
                      if (cleanRisks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: cleanRisks.map((risk) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2, right: 6),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        risk,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    return SafetyMeterPainter.getScoreColor(score);
  }
}

class SafetyMeterPainter extends CustomPainter {
  final int score;

  SafetyMeterPainter({required this.score});

  /// Computes the uniform color for the score meter circle and score text.
  /// If score is below 40, returns full red. As score increases,
  /// smoothly changes the color of the whole meter circle towards green.
  static Color getScoreColor(int score) {
    if (score < 40) {
      return const Color(0xFFDC2626); // Full Red below 40
    } else if (score < 60) {
      final double t = (score - 40) / 20.0;
      return Color.lerp(const Color(0xFFDC2626), const Color(0xFFEA580C), t)!;
    } else if (score < 75) {
      final double t = (score - 60) / 15.0;
      return Color.lerp(const Color(0xFFEA580C), const Color(0xFFD97706), t)!;
    } else if (score < 85) {
      final double t = (score - 75) / 10.0;
      return Color.lerp(const Color(0xFFD97706), const Color(0xFF22C55E), t)!;
    } else {
      final double t = ((score - 85) / 15.0).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF22C55E), const Color(0xFF16A34A), t)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width / 2, size.height / 2);
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double strokeWidth = 24.0;

    // Track arc: 240 degrees (4.18879 radians), starting at 150 degrees (2.61799 radians)
    // 150° is bottom-left, sweeping 240° clockwise over top to 390° / 30° (bottom-right)
    const double startAngle = 2.61799;
    const double sweepAngle = 4.18879;

    final Color meterColor = getScoreColor(score);

    // 1. Draw the background gauge track with subtle score tint
    final Paint trackPaint = Paint()
      ..color = Color.lerp(Colors.grey.shade200, meterColor, 0.12)!
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    final double normalizedScore = (score / 100.0).clamp(0.0, 1.0);
    if (normalizedScore <= 0.0) return;

    // 2. Solid active meter arc without gradient along the path.
    // The entire active sweep, caps, and score number share the exact same meterColor.
    final double activeSweep = sweepAngle * normalizedScore;
    if (activeSweep > 0.0) {
      final Paint activePaint = Paint()
        ..color = meterColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SafetyMeterPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}