import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    bool isSavedReport = false;
    if (arguments is Map<String, dynamic>) {
      source = arguments['source'] ?? source;
      destination = arguments['destination'] ?? destination;
      role = (arguments['role']?.toString().toLowerCase() ?? 'traveler');
      isSavedReport = arguments['isSavedReport'] == true ||
          arguments['fromSavedReports'] == true ||
          arguments['savedReportId'] != null ||
          arguments['reportId'] != null;
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
    final int score = (overallScore != null) ? (overallScore as num).round() : 80;

    final problematicSegmentsRaw = analysis['problematic_segments'];
    final List<dynamic> rawProblematic =
        (problematicSegmentsRaw is List) ? problematicSegmentsRaw : [];

    // Only segments with low safety scores (< 85) belong in "Regions to Watch Out For"
    final List<dynamic> problematicSegments = rawProblematic.where((segment) {
      if (segment is! Map) return false;
      final rawScore = segment['safety_score'];
      final double scoreVal = (rawScore is num) ? rawScore.toDouble() : 100.0;
      // High-safety segments (>= 85) are safe to travel and must never be shown as danger watch-outs
      return scoreVal < 85.0;
    }).toList();

    final segmentResultsRaw = analysis['segment_results'];
    final List<dynamic> segmentResults =
        (segmentResultsRaw is List) ? segmentResultsRaw : [];

    final travelDate = analysis['travel_date']?.toString();
    final travelTime = analysis['travel_time']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCanvas,
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
            icon: const Icon(Icons.share_outlined, color: AppTheme.darkNavy),
            tooltip: 'Export Travel Brief',
            onPressed: () {
              _showTravelBriefSheet(context, analysis, source, destination);
            },
          ),
          IconButton(
            icon: const Icon(Icons.emergency_outlined, color: Color(0xFFDC2626)),
            tooltip: 'Expressway Emergency SOS',
            onPressed: () {
              _showEmergencySheet(context, analysis['emergency_directory']);
            },
          ),
          if (!isSavedReport)
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
              // OFFLINE TUNNEL CACHE BANNER
              if (analysis['is_offline_cached'] == true) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.offline_bolt_rounded, size: 20, color: Color(0xFFB45309)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline Cache Active: Highway intelligence saved for tunnel & low-connectivity transit.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(
                        painter: SafetyMeterPainter(score: score),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$score',
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: _getScoreColor(score),
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(score).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _getScoreColor(score).withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  _getRiskLabel(score).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _getScoreColor(score),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _getOverallVerdict(score),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PROACTIVE SMART DEPARTURE TIMING OPTIMIZER
              if (analysis['departure_optimization'] != null) ...[
                _buildDepartureOptimizerCard(
                  analysis['departure_optimization'],
                  isTraveler: !isPlanner,
                ),
                const SizedBox(height: 16),
              ],

              // CORRIDOR ELEVATION & RISK PROFILE
              _buildElevationProfileCard(analysis['elevation_profile'], segmentResults),

              const SizedBox(height: 32),

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
                    return _buildSegmentCard(
                      segment,
                      isPlanner: isPlanner,
                      travelDate: travelDate,
                      travelTime: travelTime,
                    );
                  }),
              ],

              if (!isSavedReport) ...[
                const SizedBox(height: 36),

                // SAVE REPORT BUTTON (On report analysis page)
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _reportSaved
                        ? const LinearGradient(
                            colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_reportSaved ? const Color(0xFF16A34A) : const Color(0xFF1E3A8A)).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                            color: Colors.white,
                          ),
                    label: Text(
                      _isSavingReport
                          ? 'Saving Report...'
                          : _reportSaved
                              ? 'Report Saved to Archive'
                              : 'Save Report to Archive',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // BOTTOM ACTION BUTTON (Live updates / Return to Chat)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(
                          context,
                          isPlanner
                              ? {'action': 'back_to_chat'}
                              : {'action': 'live_updates'},
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPlanner
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.add_location_alt_rounded,
                            color: const Color(0xFF1D4ED8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPlanner ? 'Back to Chat Assistant' : 'Share Live Road Updates',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Viewing Archived Saved Report',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
        return 'Ghat Foothills & Approach Area';
      case 'R4':
        return 'Bhor Ghat Mountain Pass & Hairpin Incline';
      case 'R5':
        return 'Khandala-Lonavala Crest & Plateau Zone';
      case 'R6':
        return 'Sahyadri Descending Plateau Area';
      case 'R7':
        return 'Pune Metropolitan Approach Corridor';
      case 'R8':
        return 'Pune Bypass & Urban Arterial';
      default:
        return 'Corridor Route Area';
    }
  }

  String _getSectorAdvisory(String code, {bool isRain = false}) {
    String base;
    switch (code) {
      case 'R1':
        base = 'High-density urban commuter flow with frequent flyovers. Maintain safe following buffer and anticipate sudden lane merges near Vashi and CBD Belapur.';
        break;
      case 'R2':
        base = 'Open 6-lane high-speed expressway plain. Optimal fluid cruising area; maintain designated fast-lane discipline and avoid sudden overtaking.';
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
        base = 'Standard expressway route area. Maintain designated lane discipline and recommended cruising speed.';
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

  Widget _buildSegmentCard(
    dynamic segment, {
    bool isPlanner = false,
    String? travelDate,
    String? travelTime,
  }) {
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

    // Weather / Forecast Telemetry
    final weather = segment['weather_result'];
    String cond = 'Clear';
    String tempStr = '--';
    String humidityStr = '40% Humidity';
    String visibilityStr = '10.0 km';
    String visibilityDesc = 'Optimal Sightlines';
    String precipitationStr = 'No Rain Forecast';
    String roadGripStr = 'Dry Pavement';
    double? visKm;
    double? rainMm;
    double? windKmh;
    int? humidityVal;
    bool isRain = false;

    if (weather is Map) {
      cond = weather['weather_condition']?.toString() ?? 'Clear';
      final temp = weather['temperature_c'];
      if (temp != null) {
        tempStr = '${temp is num ? temp.round() : temp}°C';
      }
      final rh = weather['humidity_percent'] ?? weather['relative_humidity'] ?? weather['humidity'];
      if (rh != null && rh is num) {
        humidityVal = rh.toInt();
        humidityStr = '$humidityVal% Humidity';
      }

      final vk = weather['visibility_km'];
      if (vk != null && vk is num) {
        visKm = vk.toDouble();
        visibilityStr = '${visKm.toStringAsFixed(1)} km';
      }
      final vc = weather['visibility_condition']?.toString();
      if (vc != null && vc.isNotEmpty) {
        visibilityDesc = vc;
      }

      final rm = weather['rainfall_mm'];
      if (rm != null && rm is num) {
        rainMm = rm.toDouble();
      }
      final rc = weather['rain_condition']?.toString() ?? weather['rain']?.toString();
      isRain = (rainMm != null && rainMm > 0) || (rc != null && rc.toLowerCase() != 'no rain' && rc.toLowerCase() != 'none');
      if (isRain) {
        precipitationStr = (rainMm != null && rainMm > 0) ? '${rainMm.toStringAsFixed(1)} mm Rain' : (rc ?? 'Rain Expected');
        roadGripStr = 'Wet Surface Caution';
      } else {
        precipitationStr = 'No Rain Forecast';
        roadGripStr = 'Dry Pavement';
      }

      final ws = weather['wind_speed_kmh'];
      if (ws != null && ws is num) {
        windKmh = ws.toDouble();
      }
    }

    // Traffic Telemetry (Traveler mode)
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

    // Risk factors / alerts (strictly genuine negative hazards)
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
              !s.contains('advance planning mode') &&
              !s.contains('corridor geometry') &&
              !s.contains('terrain geometry');
        })
        .toList();

    // Human-readable condition & safety assessment ("Why is the score this?")
    String conditionAssessment;
    final int sVal = score ?? 90;
    if (isPlanner) {
      if (sVal >= 95) {
        conditionAssessment = 'Optimal conditions predicted. Atmospheric visibility is clear ($visibilityStr), road surfaces will be dry, and forecast models project fluid transit throughout this corridor.';
      } else if (sVal >= 85) {
        conditionAssessment = 'Favorable travel conditions ($sVal/100). Standard highway speeds with normal regional terrain and calm atmospheric outlook.';
      } else if (sVal >= 70) {
        if (isRain) {
          conditionAssessment = 'Caution advised ($sVal/100). Predicted precipitation ($precipitationStr) creates wet pavement. Expect reduced traction and reduce cruising speeds.';
        } else if (visKm != null && visKm < 5.0) {
          conditionAssessment = 'Caution advised ($sVal/100). Reduced atmospheric visibility ($visibilityStr) forecast. Use low-beam headlamps and maintain safe following distance.';
        } else {
          conditionAssessment = 'Moderate caution advised ($sVal/100). Localized atmospheric variations forecast for this scheduled departure.';
        }
      } else {
        conditionAssessment = 'Adverse conditions predicted ($sVal/100). Noticeable weather or roadway hazards expected. Consider adjusting planned departure window.';
      }
    } else {
      if (sVal >= 95) {
        conditionAssessment = 'Clear route conditions. Fluid traffic flow, dry pavement, and unrestricted cruising speeds.';
      } else if (sVal >= 85) {
        conditionAssessment = 'Good travel conditions ($sVal/100). Normal traffic movement with standard mountain or urban expressway flow.';
      } else {
        conditionAssessment = 'Caution advised ($sVal/100). Live traffic delays or degraded road surface reported on this stretch.';
      }
    }

    final sectorAdvisory = _getSectorAdvisory(regCode, isRain: isRain);

    // Safe Speed Advisory
    final safeSpeedAdv = segment['safe_speed_advisory'];
    int statutorySpeed = 80;
    int recommendedSpeed = 80;
    List<String> speedReasons = [];
    if (safeSpeedAdv is Map) {
      statutorySpeed = (safeSpeedAdv['statutory_speed_kmh'] as num?)?.toInt() ?? 80;
      recommendedSpeed = (safeSpeedAdv['recommended_safe_speed_kmh'] as num?)?.toInt() ?? statutorySpeed;
      if (safeSpeedAdv['advisory_reasons'] is List) {
        speedReasons = (safeSpeedAdv['advisory_reasons'] as List).map((e) => e.toString()).toList();
      }
    }
    final bool isSpeedReduced = recommendedSpeed < statutorySpeed;

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

                      // Scheduled Target Date & Time Pill (Planner mode)
                      if (isPlanner && (travelDate != null || travelTime != null)) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.royalCobalt),
                              const SizedBox(width: 6),
                              Text(
                                'Predicted Outlook for ${travelDate ?? ''} ${travelTime ?? ''}'.trim(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.royalCobalt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Dynamic Safe Speed Limit Advisory Banner
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSpeedReduced ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSpeedReduced ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 16,
                              color: isSpeedReduced ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Recommended Safe Speed: $recommendedSpeed km/h',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isSpeedReduced ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                        ),
                                      ),
                                      if (isSpeedReduced) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(Statutory $statutorySpeed)',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF64748B),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (speedReasons.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        speedReasons.first,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSpeedReduced ? const Color(0xFF991B1B) : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Telemetry Metric Tiles
                      if (isPlanner) ...[
                        // PLANNER 3-TILE PREDICTED CONDITIONS GRID
                        Row(
                          children: [
                            // 1. Predicted Weather & Temp
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
                                            '$humidityStr${windKmh != null ? ' • ${windKmh.round()} km/h' : ''}',
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
                            // 2. Visibility & Sightlines
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
                                    const Icon(
                                      Icons.visibility_rounded,
                                      size: 18,
                                      color: AppTheme.royalCobalt,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            visibilityStr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.darkNavy,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            visibilityDesc,
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 3. Road Surface & Precipitation State
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRain ? Icons.water_rounded : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: isRain ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      roadGripStr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isRain ? const Color(0xFFD97706) : AppTheme.darkNavy,
                                      ),
                                    ),
                                    Text(
                                      precipitationStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // TRAVELER LIVE TELEMETRY TILES
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
                                            roadGripStr,
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
                      ],

                      const SizedBox(height: 10),

                      // Safety Assessment Card ("Why is the score this?")
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Safety Assessment & Outlook',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              conditionAssessment,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppTheme.darkNavy.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Sector Driving Advisory Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.navigation_rounded,
                                  size: 14,
                                  color: Color(0xFF1D4ED8),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Area Driving Advisory',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
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

  String _getRiskLabel(int score) {
    if (score < 45) return 'High Risk';
    if (score < 65) return 'Caution';
    if (score < 85) return 'Moderate';
    return 'Optimal';
  }

  String _getOverallVerdict(int score) {
    if (score < 45) return 'Hazardous conditions detected. Caution strongly advised.';
    if (score < 65) return 'Moderate adverse weather or traffic. Drive with extra care.';
    if (score < 85) return 'Generally clear corridor conditions with standard precautions.';
    return 'Optimal travel conditions along the expressway corridor.';
  }

  // ============================================================
  // PROACTIVE SMART DEPARTURE TIMING OPTIMIZER CARD
  // ============================================================

  Widget _buildDepartureOptimizerCard(dynamic opt, {bool isTraveler = true}) {
    if (opt is! Map) return const SizedBox.shrink();

    final List<dynamic> rawAlts =
        (opt['alternative_windows'] is List) ? opt['alternative_windows'] : [];

    // For traveler role, only keep current (0) and future windows (positive offsets).
    // Never show past windows (-30m, -60m) to a traveler who is already traveling/departing now.
    final List<dynamic> alts = isTraveler
        ? rawAlts.where((alt) {
            if (alt is! Map) return false;
            final num? offset = alt['offset_minutes'] as num?;
            if (offset != null) return offset >= 0;
            final String cond = (alt['condition'] ?? '').toString().toLowerCase();
            return !cond.contains('earlier');
          }).toList()
        : rawAlts;

    bool hasBetter = opt['has_better_alternative'] == true;
    String recText = opt['recommendation_text']?.toString() ?? '';

    // If traveler, ensure the recommendation does NOT suggest an earlier/past time
    if (isTraveler) {
      final num optOffset = (opt['optimal_offset_minutes'] as num?) ?? 0;
      if (optOffset < 0 || recText.toLowerCase().contains('earlier')) {
        // Find best future window from remaining alternatives
        Map<String, dynamic>? bestFuture;
        final double currentScore =
            (opt['current_safety_score'] as num?)?.toDouble() ?? 85.0;
        double bestFutureScore = currentScore;
        int bestFutureOffset = 0;

        for (final item in alts) {
          if (item is Map) {
            final num off = (item['offset_minutes'] as num?) ?? 0;
            final double s =
                (item['safety_score'] as num?)?.toDouble() ?? 0.0;
            if (off > 0 && s > bestFutureScore + 2.0) {
              bestFutureScore = s;
              bestFutureOffset = off.toInt();
              bestFuture = Map<String, dynamic>.from(item);
            }
          }
        }

        if (bestFuture != null && (bestFutureScore - currentScore) >= 3.0) {
          hasBetter = true;
          final String displayTime = bestFuture['display_time'] ?? '';
          final double diff = bestFutureScore - currentScore;
          recText =
              'Smart Timing Advice: Leaving at $displayTime ($bestFutureOffset mins later) increases safety from ${currentScore.toInt()} to ${bestFutureScore.toInt()}/100 (+${diff.toInt()} pts) with clearer conditions.';
        } else {
          hasBetter = false;
          recText =
              'Leaving now is within your safest upcoming departure window with good safety conditions.';
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasBetter ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: hasBetter ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasBetter ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasBetter ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
                  color: hasBetter ? AppTheme.electricCobalt : AppTheme.darkNavy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasBetter ? 'SMART TIMING ADVICE' : 'DEPARTURE SCHEDULE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: hasBetter ? AppTheme.electricCobalt : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasBetter ? 'Better Departure Time Available' : 'Leaving Time Verified',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          if (alts.isNotEmpty) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: alts.map((alt) {
                  if (alt is! Map) return const SizedBox.shrink();
                  final bool isCurrent = alt['is_current'] == true;
                  final String time = alt['display_time'] ?? '';
                  final double slotScore = (alt['safety_score'] as num?)?.toDouble() ?? 80.0;
                  final String cond = alt['condition'] ?? '';
                  final Color chipColor = _getScoreColor(slotScore.toInt());
                  final num? offsetNum = alt['offset_minutes'] as num?;

                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? AppTheme.electricCobalt : const Color(0xFFE2E8F0),
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                                color: isCurrent ? AppTheme.royalSapphire : AppTheme.darkNavy,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.royalSapphire,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isTraveler ? 'NOW' : 'CHOSEN',
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ] else if (offsetNum != null && offsetNum != 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  offsetNum > 0 ? '+$offsetNum m' : '$offsetNum m',
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${slotScore.toInt()}/100',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: chipColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cond,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
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
    );
  }

  // ============================================================
  // CORRIDOR ELEVATION & MOUNTAIN PROFILE CARD
  // ============================================================

  Widget _buildElevationProfileCard(dynamic profileData, List<dynamic> segments) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.terrain_rounded, color: AppTheme.royalCobalt, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CORRIDOR ELEVATION & TERRAIN PROFILE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mumbai (8m) → Bhor Ghat Peak (624m) → Pune (560m)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 185,
              width: double.infinity,
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: CustomPaint(
                painter: ElevationChartPainter(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Route Elevation Milestones from Mumbai to Pune
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWaypointChip('Mumbai', '8m', 'Start', const Color(0xFF0284C7)),
                const SizedBox(width: 8),
                _buildWaypointChip('Panvel', '14m', 'R2', const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _buildWaypointChip('Khopoli', '72m', 'R4 Base', const Color(0xFFD97706)),
                const SizedBox(width: 8),
                _buildWaypointChip('Khandala', '550m', 'R4 Ghat', const Color(0xFFEA580C)),
                const SizedBox(width: 8),
                _buildWaypointChip('Lonavala', '624m', 'Peak', const Color(0xFFDC2626), isPeak: true),
                const SizedBox(width: 8),
                _buildWaypointChip('Talegaon', '582m', 'R6 Plateau', const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _buildWaypointChip('Pune', '560m', 'Destination', const Color(0xFF059669)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointChip(String name, String meters, String tag, Color color, {bool isPeak = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPeak ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPeak ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isPeak ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$meters MSL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPeak ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HIGHWAY EMERGENCY SOS DIRECTORY SHEET
  // ============================================================

  void _showEmergencySheet(BuildContext context, dynamic emergencyDir) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: const [
                    Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expressway Emergency & SOS Directory',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          Text(
                            'Mumbai-Pune Expressway (NH-48) 24x7 Assistance',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  children: [
                    const Text(
                      '24x7 EMERGENCY DISPATCH HOTLINES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    _buildEmergencyContactTile(
                      ctx,
                      title: 'IRB Expressway Control Room (24x7)',
                      phone: '9822498224',
                      displayPhone: '98224 98224',
                      desc: 'Ambulance, Heavy Towing Crane & Highway Patrol SOS',
                      isHighPriority: true,
                    ),
                    _buildEmergencyContactTile(
                      ctx,
                      title: 'National Highway Patrol (MSRDC)',
                      phone: '1033',
                      displayPhone: '1033',
                      desc: 'Toll-free Expressway Emergency Helpline',
                      isHighPriority: true,
                    ),
                    _buildEmergencyContactTile(
                      ctx,
                      title: 'Maharashtra Highway Police Control',
                      phone: '02025651515',
                      displayPhone: '020-25651515',
                      desc: 'State Highway Police HQ Control Room',
                      isHighPriority: false,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NEAREST TRAUMA CARE HOSPITALS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    _buildTraumaTile(
                      ctx,
                      name: 'MGM Hospital & Medical College',
                      location: 'Kamothe / Panvel (km 34)',
                      phone: '02227437900',
                      displayPhone: '022-27437900',
                      badge: 'Level 1 Trauma',
                    ),
                    _buildTraumaTile(
                      ctx,
                      name: 'Jakhotia Trauma Care Hospital',
                      location: 'Khopoli Phata (km 70 - Ghat Base)',
                      phone: '02192263300',
                      displayPhone: '02192-263300',
                      badge: 'Ghat Entry Trauma',
                    ),
                    _buildTraumaTile(
                      ctx,
                      name: 'Sanjeevani Critical Care Hospital',
                      location: 'Lonavala (km 88 - Ghat Crest)',
                      phone: '02114273545',
                      displayPhone: '02114-273545',
                      badge: 'Mountain Crest Care',
                    ),
                    _buildTraumaTile(
                      ctx,
                      name: 'Lokmanya Hospital for Trauma',
                      location: 'Nigdi / Pune (km 138)',
                      phone: '02030717500',
                      displayPhone: '020-30717500',
                      badge: 'Neuro & Ortho Care',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'AUTHORIZED REST & FUEL PLAZAS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    _buildPlazaTile(
                      name: 'Khalapur Food Mall (Pune-bound, km 38)',
                      amenities: 'Fuel • EV Fast Chargers • Medical Kit • Food Court',
                    ),
                    _buildPlazaTile(
                      name: 'Ozarde Food Plaza (Mumbai-bound, km 78)',
                      amenities: 'Fuel • Tire Mechanics • Towing Assistance • Restrooms',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyContactTile(
    BuildContext ctx, {
    required String title,
    required String phone,
    required String displayPhone,
    required String desc,
    required bool isHighPriority,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighPriority ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighPriority ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighPriority ? const Color(0xFFDC2626) : AppTheme.darkNavy,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.darkNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  displayPhone,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isHighPriority ? const Color(0xFFDC2626) : AppTheme.royalSapphire,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.darkNavy),
            tooltip: 'Copy Number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $displayPhone to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTraumaTile(
    BuildContext ctx, {
    required String name,
    required String location,
    required String phone,
    required String displayPhone,
    required String badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.darkNavy),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.royalCobalt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(location, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(displayPhone, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.royalCobalt)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.darkNavy),
            tooltip: 'Copy Number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $name phone to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlazaTile({required String name, required String amenities}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_rounded, size: 20, color: AppTheme.royalCobalt),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.darkNavy)),
                const SizedBox(height: 2),
                Text(amenities, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXECUTIVE TRAVEL ADVISORY BRIEF EXPORT
  // ============================================================

  void _showTravelBriefSheet(BuildContext context, Map<String, dynamic> analysis, String source, String destination) {
    final int overallScore = (analysis['overall_safety_score'] as num?)?.round() ?? 80;
    final String date = analysis['travel_date'] ?? 'Today';
    final String time = analysis['travel_time'] ?? 'Now';
    final List<dynamic> segments = (analysis['segment_results'] is List) ? analysis['segment_results'] : [];

    final StringBuffer brief = StringBuffer();
    brief.writeln('====================================');
    brief.writeln('  MUMBAI-PUNE TRAVEL ADVISORY BRIEF');
    brief.writeln('====================================');
    brief.writeln('Route: $source → $destination');
    brief.writeln('Departure: $date at $time');
    brief.writeln('Overall Safety Score: $overallScore / 100 (${_getRiskLabel(overallScore)})');
    brief.writeln('------------------------------------');
    brief.writeln('CORRIDOR WAYPOINTS & SAFE SPEEDS:');
    for (final s in segments) {
      if (s is Map) {
        final title = _resolveSegmentTitle(s);
        final segScore = s['safety_score'] ?? '--';
        final safeSpeed = s['safe_speed_advisory']?['recommended_safe_speed_kmh'] ?? 80;
        final cond = s['weather_result']?['weather_condition'] ?? 'Clear';
        brief.writeln('• $title: $segScore/100 | $cond | Safe Speed: $safeSpeed km/h');
      }
    }
    brief.writeln('------------------------------------');
    brief.writeln('EMERGENCY HOTLINES:');
    brief.writeln('• IRB Expressway SOS: 98224 98224');
    brief.writeln('• Highway Patrol: 1033');
    brief.writeln('====================================');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.assignment_turned_in_rounded, color: AppTheme.royalCobalt),
              SizedBox(width: 8),
              Text('Travel Advisory Brief', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 340),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              child: Text(
                brief.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalCobalt,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: brief.toString()));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Travel Advisory Brief copied to clipboard!')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ElevationChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 38.0;
    const double rightMargin = 16.0;
    const double topMargin = 22.0;
    const double bottomMargin = 30.0;

    final double chartW = size.width - leftMargin - rightMargin;
    final double chartH = size.height - topMargin - bottomMargin;

    const double maxElevation = 700.0;

    // 1. Draw horizontal gridlines & Y-axis labels (0m, 200m, 400m, 600m)
    final yTicks = [0.0, 200.0, 400.0, 600.0];
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    for (final elev in yTicks) {
      final double y = topMargin + chartH - ((elev / maxElevation) * chartH);

      // Light horizontal gridline
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Y-axis label text
      final tp = TextPainter(
        text: TextSpan(
          text: '${elev.toInt()}m',
          style: const TextStyle(
            fontSize: 9.0,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 5.0, y - tp.height / 2));
    }

    // Y-axis title / unit header
    final yTitleTp = TextPainter(
      text: const TextSpan(
        text: 'm MSL',
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    yTitleTp.layout();
    yTitleTp.paint(canvas, Offset(leftMargin - yTitleTp.width - 4.0, 4.0));

    // 2. Draw Y-axis and X-axis lines
    final axisPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5;

    // Y-axis line
    canvas.drawLine(
      Offset(leftMargin, topMargin - 4.0),
      Offset(leftMargin, topMargin + chartH),
      axisPaint,
    );

    // X-axis baseline
    canvas.drawLine(
      Offset(leftMargin, topMargin + chartH),
      Offset(size.width - rightMargin + 4.0, topMargin + chartH),
      axisPaint,
    );

    // 3. Elevation Waypoints along the Mumbai-Pune corridor
    // (normalized_x [0.0 to 1.0], elevation_m, short_name)
    final waypoints = [
      (0.00, 8.0, 'Mumbai'),
      (0.18, 14.0, 'Panvel'),
      (0.35, 48.0, 'Khalapur'),
      (0.46, 72.0, 'Khopoli'),
      (0.58, 550.0, 'Ghat'),
      (0.68, 624.0, 'Lonavala'),
      (0.84, 582.0, 'Talegaon'),
      (1.00, 560.0, 'Pune'),
    ];

    Offset toCanvas(double normX, double elevM) {
      final double x = leftMargin + (normX * chartW);
      final double y = topMargin + chartH - ((elevM / maxElevation) * chartH);
      return Offset(x, y);
    }

    final Path path = Path();
    final Path fillPath = Path();

    final firstPt = toCanvas(waypoints[0].$1, waypoints[0].$2);
    path.moveTo(firstPt.dx, firstPt.dy);
    fillPath.moveTo(firstPt.dx, topMargin + chartH);
    fillPath.lineTo(firstPt.dx, firstPt.dy);

    for (int i = 0; i < waypoints.length - 1; i++) {
      final p0 = toCanvas(waypoints[i].$1, waypoints[i].$2);
      final p1 = toCanvas(waypoints[i + 1].$1, waypoints[i + 1].$2);
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final lastPt = toCanvas(waypoints.last.$1, waypoints.last.$2);
    fillPath.lineTo(lastPt.dx, topMargin + chartH);
    fillPath.close();

    // 4. Fill gradient below elevation curve
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2563EB).withValues(alpha: 0.32),
          const Color(0xFF1E3A8A).withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTWH(leftMargin, topMargin, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw elevation curve stroke
    final Paint linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 6. Draw dots & X-axis labels
    final Paint dotPaint = Paint()..color = const Color(0xFF1E3A8A);
    final Paint dotInner = Paint()..color = Colors.white;
    final Paint peakDot = Paint()..color = const Color(0xFFDC2626);

    for (final wp in waypoints) {
      final c = toCanvas(wp.$1, wp.$2);
      final bool isPeak = (wp.$3 == 'Lonavala');

      if (isPeak) {
        canvas.drawCircle(c, 5.0, peakDot);
        canvas.drawCircle(c, 2.5, dotInner);

        // Draw Peak Callout
        final peakTp = TextPainter(
          text: const TextSpan(
            text: '624m Peak',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFFDC2626),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        peakTp.layout();
        peakTp.paint(canvas, Offset(c.dx - peakTp.width / 2, c.dy - 16.0));
      } else {
        canvas.drawCircle(c, 3.8, dotPaint);
        canvas.drawCircle(c, 2.0, dotInner);
      }

      // X-axis tick
      canvas.drawLine(
        Offset(c.dx, topMargin + chartH),
        Offset(c.dx, topMargin + chartH + 4.0),
        axisPaint,
      );

      // X-axis label (Segment Name + Meters)
      final xLabelTp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${wp.$3}\n',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: isPeak ? FontWeight.w900 : FontWeight.w700,
                color: isPeak ? const Color(0xFFDC2626) : const Color(0xFF334155),
              ),
            ),
            TextSpan(
              text: '${wp.$2.toInt()}m',
              style: TextStyle(
                fontSize: 8.0,
                fontWeight: FontWeight.w600,
                color: isPeak ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      xLabelTp.layout();

      // Ensure labels don't get clipped on edges
      double labelX = c.dx - (xLabelTp.width / 2);
      if (labelX < 0) labelX = 0;
      if (labelX + xLabelTp.width > size.width) labelX = size.width - xLabelTp.width;

      xLabelTp.paint(canvas, Offset(labelX, topMargin + chartH + 5.0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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