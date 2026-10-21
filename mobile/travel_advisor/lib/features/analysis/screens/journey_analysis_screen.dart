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

    // Only segments with genuine hazards or low safety scores (< 80) belong in "Caution Areas"
    final List<dynamic> problematicSegments = rawProblematic.where((segment) {
      if (segment is! Map) return false;
      final rawScore = segment['safety_score'];
      final double scoreVal = (rawScore is num) ? rawScore.toDouble() : 100.0;
      if (scoreVal < 80.0) return true;
      // High-safety segments (>= 80) are safe to travel and must never be shown as caution areas unless active critical hazard exists
      final reasonsRaw = segment['reasons'];
      if (reasonsRaw is List) {
        for (final r in reasonsRaw) {
          final s = r.toString().toLowerCase();
          if (s.contains('no rain') || s.contains('no delay') || s.contains('no delays') || s.contains('optimal') || s.contains('smooth') || s.contains('dry') || s.contains('clear') || s.contains('safe') || s.contains('normal flow') || s.contains('free flow') || s.contains('normal traffic') || s.contains('fluid flow')) {
            continue;
          }
          if ((s.contains('rain') && !s.contains('no rain')) ||
              (s.contains('fog') && !s.contains('no fog')) ||
              (s.contains('delay') && !s.contains('no delay')) ||
              s.contains('bottleneck') ||
              (s.contains('hazard') && !s.contains('no hazard')) ||
              s.contains('standstill') ||
              s.contains('landslide') ||
              s.contains('flooding')) {
            return true;
          }
        }
      }
      return false;
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
              Navigator.pushNamed(context, AppRoutes.emergencySos);
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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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

              // CAUTION AREAS SECTION
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Caution Areas',
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'All Route Areas Clear',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.forestGreen,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'No caution areas detected on this route. Road conditions and traffic are safe.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.forestGreen,
                                          ),
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

  static const Map<String, _SectorGeoProfile> _sectorGeoProfiles = {
    'R1': _SectorGeoProfile(
      baseElevM: 8,
      peakElevM: 16,
      gradientPct: 0.2,
      terrainDesc: 'coastal alluvial plain',
      keyFeature: 'multi-tier flyover interchanges and commuter merges',
    ),
    'R2': _SectorGeoProfile(
      baseElevM: 16,
      peakElevM: 42,
      gradientPct: 0.4,
      terrainDesc: 'open Konkan lowland plain',
      keyFeature: '6-lane unsheltered straightaways with crosswind exposure',
    ),
    'R3': _SectorGeoProfile(
      baseElevM: 42,
      peakElevM: 95,
      gradientPct: 1.8,
      terrainDesc: 'Western Ghats foothill approach',
      keyFeature: 'Khalapur toll deceleration zone and freight climbing merges',
    ),
    'R4': _SectorGeoProfile(
      baseElevM: 95,
      peakElevM: 550,
      gradientPct: 4.6,
      terrainDesc: 'steep Western Ghats mountain pass (Bhor Ghat)',
      keyFeature: 'continuous reverse hairpin bends, Adoshi tunnel, and 1:21 incline grade',
    ),
    'R5': _SectorGeoProfile(
      baseElevM: 550,
      peakElevM: 625,
      gradientPct: 1.2,
      terrainDesc: 'Sahyadri crest canyon summit',
      keyFeature: 'elevated Khandala viaduct gorge bridge and Amrutanjan descent curve',
    ),
    'R6': _SectorGeoProfile(
      baseElevM: 585,
      peakElevM: 622,
      gradientPct: -0.8,
      terrainDesc: 'upper Deccan volcanic basalt plateau',
      keyFeature: 'twin Kamshet tunnels and sweeping high-speed plateau curves',
    ),
    'R7': _SectorGeoProfile(
      baseElevM: 570,
      peakElevM: 585,
      gradientPct: -0.5,
      terrainDesc: 'Deccan agricultural highland basin',
      keyFeature: 'Urse Toll Plaza approach and Talegaon MIDC freight merges',
    ),
    'R8': _SectorGeoProfile(
      baseElevM: 560,
      peakElevM: 570,
      gradientPct: -0.3,
      terrainDesc: 'Pune metropolitan western plateau',
      keyFeature: 'Dehu Road arterial bypass transition and narrowing expressway terminus',
    ),
  };

  /// Generates a fully dynamic, context-aware driving advisory in point-wise format
  /// combining sector topography, elevation, live weather reports, and TomTom traffic congestion.
  /// (Strictly no brackets or bracket-like label headers; clean point-wise bullet items).
  String _buildDynamicAreaAdvisory({
    required String code,
    required String title,
    required bool isRain,
    required double? rainMm,
    required String precipitationStr,
    required bool isNight,
    required double? visKm,
    required double? windKmh,
    required double? tempC,
    required int delayMinutes,
    required String speedText,
    required int statutorySpeed,
    required int recommendedSpeed,
  }) {
    final List<String> points = [];
    final geo = _sectorGeoProfiles[code] ?? const _SectorGeoProfile(
      baseElevM: 100,
      peakElevM: 200,
      gradientPct: 1.0,
      terrainDesc: 'expressway corridor terrain',
      keyFeature: 'standard expressway grade and multi-lane flow',
    );

    // 1. Sector Elevation & Gradient Incline Physics
    if (code == 'R4') {
      if (tempC != null && tempC >= 32.0) {
        points.add(
          'Steep 4.6% mountain incline climbing from 95m to 550m ASL (+455m vertical climb); ambient temperature of ${tempC.toStringAsFixed(0)}°C under heavy uphill throttle escalates engine coolant temperatures; monitor dashboard gauges.',
        );
      } else {
        points.add(
          'Steep 4.6% mountain incline climbing from 95m to 550m ASL (+455m vertical gain over 10 km); engage 2nd or 3rd gear for progressive engine braking on descents and avoid riding foot brakes continuously to eliminate dangerous brake fade.',
        );
      }
      points.add(
        'Overloaded commercial vehicles crawl at 15-25 km/h in left crawler lanes; maintain at least a 40m vehicle cushion and never overtake on blind reverse curves or inside Adoshi tunnel.',
      );
    } else if (code == 'R5') {
      points.add(
        'Corridor summit at ${geo.peakElevM}m ASL; moderate speeds to $recommendedSpeed km/h across elevated Khandala viaduct decks to mitigate gorge wind buffeting, and watch for sudden tourist vehicle slowdowns near Lonavala exit ramps.',
      );
    } else if (code == 'R6') {
      points.add(
        'Deccan volcanic plateau at ~${geo.peakElevM}m ASL with rolling -0.8% grade; maintain steady center-lane discipline at $recommendedSpeed km/h and decelerate before entering twin Kamshet tunnels (300m and 1.2 km) for visual light-adaptation.',
      );
    } else if (code == 'R7') {
      points.add(
        'Plateau descent corridor at ~${geo.baseElevM}m ASL; anticipate rapid deceleration waves and heavy container freight merging from Talegaon industrial corridors approaching Urse Toll Plaza.',
      );
    } else if (code == 'R1' || code == 'R2') {
      points.add(
        'Open coastal lowland plain at ~${(geo.baseElevM + geo.peakElevM) ~/ 2}m ASL; maintain center-lane discipline between 80-$statutorySpeed km/h and reserve the extreme right lane strictly for overtaking slower vehicles.',
      );
    } else {
      points.add(
        'Pune metropolitan terminus at ~${geo.baseElevM}m ASL; transition smoothly from 100 km/h expressway cruising down to $recommendedSpeed km/h as the route narrows into Dehu Road urban bypass intersections.',
      );
    }

    // 2. Dynamic Road Surface & Friction Precaution
    if (isRain) {
      if (code == 'R4' || code == 'R5') {
        final rainAmt = (rainMm != null && rainMm > 0) ? '${rainMm.toStringAsFixed(1)} mm/h' : precipitationStr;
        points.add(
          'Mountain asphalt is slick due to $rainAmt; friction is reduced. Never apply abrupt steering jerks or emergency braking on wet hairpin bends.',
        );
      } else {
        points.add(
          'Wet pavement ($precipitationStr) creates hydroplaning risk above $recommendedSpeed km/h; steer clear of standing water near shoulders and double your following gap.',
        );
      }
    } else if (visKm != null && visKm < 3.0) {
      points.add(
        'Mountain mist restricts forward sightlines to ${visKm.toStringAsFixed(1)} km; operate low-beam headlights and follow road cat\'s-eye reflective lane studs.',
      );
    } else if (windKmh != null && windKmh > 25.0) {
      points.add(
        'Elevated crosswinds of ${windKmh.toStringAsFixed(0)} km/h across unsheltered spans; keep a firm two-handed grip on the steering wheel when exiting rock cuttings and tunnels.',
      );
    } else {
      final surfaceText = tempC != null && tempC >= 32.0 ? 'warm asphalt (${tempC.toStringAsFixed(0)}°C)' : 'dry pavement';
      points.add(
        'Clear $surfaceText provides stable grip; maintain a standard 3-second safe following buffer from lead vehicles during highway cruising.',
      );
    }

    // 3. Dynamic Safe Speed Target Calculation
    if (statutorySpeed > recommendedSpeed) {
      final diff = statutorySpeed - recommendedSpeed;
      final String reason = isRain
          ? 'slick road conditions'
          : (visKm != null && visKm < 3.5 ? 'curtailed visibility' : (geo.gradientPct.abs() > 3.0 ? 'steep mountain curves' : 'traffic queue management'));
      points.add(
        'Safe cruising speed is dynamically dialed down to $recommendedSpeed km/h (-$diff km/h from the $statutorySpeed km/h legal limit) to accommodate $reason.',
      );
    }

    // 4. Traffic Congestion Protocol (Only when there is an active delay >= 8m - zero duplicate free-flow repetition)
    if (delayMinutes >= 8) {
      points.add(
        'Active congestion queue ahead (+${delayMinutes}m delay); avoid erratic lane switching, prepare for braking waves, and remain aligned with traffic flow.',
      );
    }

    // 5. Night Driving Protocol
    if (isNight) {
      points.add(
        'Ambient lighting is limited on unlit highway sectors; dip high-beams when following within 150m of other vehicles to prevent blinding drivers ahead.',
      );
    }

    return points.map((p) => '• $p').join('\n\n');
  }

  /// Builds a comprehensive, dynamic safety assessment and outlook in point-wise format
  /// that quotes real weather metrics, elevation, and predictive horizons.
  /// (Strictly no brackets or bracket-like label headers; clean point-wise bullet items).
  String _buildDynamicSafetyAssessment({
    required String code,
    required int sVal,
    required String title,
    required bool isRain,
    required double? rainMm,
    required String precipitationStr,
    required bool isNight,
    required double? visKm,
    required double? windKmh,
    required double? tempC,
    required int delayMinutes,
    required String speedText,
    required int statutorySpeed,
    required int recommendedSpeed,
    required bool isPlanner,
    required String? travelDate,
    required String? travelTime,
  }) {
    final List<String> points = [];
    final geo = _sectorGeoProfiles[code] ?? const _SectorGeoProfile(
      baseElevM: 100,
      peakElevM: 200,
      gradientPct: 1.0,
      terrainDesc: 'expressway corridor terrain',
      keyFeature: 'standard expressway grade and multi-lane flow',
    );

    // 1. Safety Score & Machine Learning Sensor Fusion Rating
    final String statusLabel = sVal >= 85
        ? 'Optimal Travel Safety'
        : (sVal >= 75
            ? 'Good Travel Conditions'
            : (sVal >= 60 ? 'Moderate Caution Advised' : 'Elevated Hazard Warning'));
    final String statusSummary = sVal >= 80
        ? 'all sensor fusion indicators remain comfortably within safe operational thresholds.'
        : (sVal >= 65
            ? 'environmental or topographical friction variance requires active driver attention.'
            : 'adverse weather or geometric risk factors active; defensive speed moderation required.');
    points.add('Overall safety rating is $statusLabel ($sVal/100) — $statusSummary');

    // 2. Dynamic Elevation & Topographical Classification
    final elevDelta = (geo.peakElevM - geo.baseElevM).abs();
    if (code == 'R4') {
      points.add(
        'Mountain pass climbing steeply from ${geo.baseElevM}m to ${geo.peakElevM}m ASL (+$elevDelta m vertical rise over 9.8 km) across a ${geo.gradientPct}% (1:21) incline grade with ${geo.keyFeature}.',
      );
    } else if (code == 'R5') {
      points.add(
        'Highest expressway corridor crest at ${geo.peakElevM}m ASL summit with rolling ${geo.gradientPct}% grade across ${geo.keyFeature}.',
      );
    } else if (code == 'R6' || code == 'R7') {
      points.add(
        'Elevated ${geo.terrainDesc} at ${geo.baseElevM}-${geo.peakElevM}m ASL with ${geo.gradientPct}% gradient and ${geo.keyFeature}.',
      );
    } else if (code == 'R1' || code == 'R2') {
      points.add(
        'Lowland ${geo.terrainDesc} at ${geo.baseElevM}-${geo.peakElevM}m ASL with near-level ${geo.gradientPct}% grade and ${geo.keyFeature}.',
      );
    } else {
      points.add(
        'Metropolitan plateau at ~${geo.baseElevM}m ASL transitioning smoothly into ${geo.keyFeature}.',
      );
    }

    // 3. Dynamic Road Friction & Weather Telemetry
    if (isRain) {
      final double mu = (rainMm != null && rainMm > 7.5) ? 0.35 : ((rainMm != null && rainMm > 2.5) ? 0.48 : 0.60);
      final int gripPct = (mu / 0.82 * 100).round();
      final int stoppingPct = ((0.82 / mu - 1.0) * 100).round();
      final rainValStr = rainMm != null && rainMm > 0 ? '${rainMm.toStringAsFixed(1)} mm/h' : precipitationStr;
      points.add(
        'Active precipitation ($rainValStr) degrades tire surface grip to $gripPct% (friction coefficient μ ≈ ${mu.toStringAsFixed(2)}); emergency stopping distance expands by +$stoppingPct%.',
      );
    } else {
      final tempText = tempC != null ? ' (asphalt surface temp ~${(tempC + 10).round()}°C at ${tempC.toStringAsFixed(0)}°C ambient)' : '';
      points.add(
        'Dry road surface$tempText yields nominal 100% tire adhesion (friction coefficient μ ≈ 0.82) with predictable vehicle braking response.',
      );
    }

    // 4. Sightlines & Atmospheric Conditions
    if (visKm != null && visKm < 3.5) {
      points.add(
        'Atmospheric sightlines curtailed to ${visKm.toStringAsFixed(1)} km due to mist and low cloud condensation; safe reaction buffer requires speeds capped at $recommendedSpeed km/h.',
      );
    } else if (windKmh != null && windKmh > 25.0) {
      points.add(
        'Elevated crosswinds of ${windKmh.toStringAsFixed(0)} km/h across open highway spans and elevated bridges require active two-handed steering stabilization.',
      );
    } else {
      final windStr = (windKmh != null && windKmh > 5.0) ? '${windKmh.toStringAsFixed(0)} km/h light airflow' : 'calm atmospheric airflow';
      points.add(
        'Forward visibility is optimal at ${visKm != null ? '${visKm.toStringAsFixed(0)} km' : '10+ km'} with $windStr, ensuring clear preview of forward traffic.',
      );
    }

    // 5. Severe Traffic Congestion Bottleneck (Only if severe delay >= 12m to prevent duplicate traffic reports)
    if (delayMinutes >= 12) {
      points.add(
        'Severe traffic queue causing a +${delayMinutes}m delay (traffic crawling at $speedText); elevated rear-end collision hazard at the tail of the slowdown.',
      );
    }

    // 6. Predictive Outlook
    if (isPlanner && (travelDate != null || travelTime != null)) {
      final dt = '${travelDate ?? ''} ${travelTime ?? ''}'.trim();
      points.add(
        'Projected outlook for $dt: expect ${isRain ? 'wet asphalt requiring conservative cornering' : (isNight ? 'unlit nighttime conditions requiring high-beam moderation' : 'clear daylight cruising conditions')}.',
      );
    } else {
      points.add(
        sVal >= 75
            ? 'Corridor conditions remain stable with low incident probability over the current travel horizon.'
            : 'Defensive driving, increased following distance, and speed moderation strongly advised.',
      );
    }

    return points.map((p) => '• $p').join('\n\n');
  }

  /// Dynamically computes statutory and recommended speeds based on sector
  /// topography, government limits, live rainfall, visibility, and TomTom traffic speed.
  Map<String, dynamic> _computeDynamicSafeSpeed({
    required String regCode,
    required dynamic safeSpeedAdv,
    required bool isRain,
    required double? rainMm,
    required String precipitationStr,
    required bool isNight,
    required double? visKm,
    required double? windKmh,
    required int delayMinutes,
    required String speedText,
  }) {
    // 1. Statutory Speed Limit by Expressway Sector
    int statutorySpeed = 80;
    if (regCode == 'R4' || regCode == 'R5') {
      statutorySpeed = 50; // Strict mountain pass statutory limit
    } else if (regCode == 'R2' || regCode == 'R6') {
      statutorySpeed = 100; // Open 6-lane plain expressway limit
    } else if (regCode == 'R8') {
      statutorySpeed = 60; // Urban arterial limit
    } else {
      statutorySpeed = 80; // Approach / transition zones
    }

    // If backend provided an explicit statutory speed, respect it
    if (safeSpeedAdv is Map && safeSpeedAdv['statutory_speed_kmh'] is num) {
      final s = (safeSpeedAdv['statutory_speed_kmh'] as num).toInt();
      if (s > 0) statutorySpeed = s;
    }

    int recommendedSpeed = statutorySpeed;
    final List<String> reasons = [];

    // 2. Weather Deductions
    if (isRain) {
      if (rainMm != null && rainMm >= 7.5) {
        recommendedSpeed -= 25;
        reasons.add('Heavy downpour (${rainMm.toStringAsFixed(1)} mm/h) - high hydroplaning risk & wet braking distance');
      } else {
        recommendedSpeed -= 15;
        reasons.add('Wet asphalt ($precipitationStr) - tire traction reduced by 30%');
      }
    }

    if (visKm != null && visKm < 2.5) {
      recommendedSpeed -= 20;
      reasons.add('Dense fog/mist cutting visibility to ${visKm.toStringAsFixed(1)} km');
    } else if (visKm != null && visKm < 5.0) {
      recommendedSpeed -= 10;
      reasons.add('Haze/mist reducing forward sightlines to ${visKm.toStringAsFixed(1)} km');
    }

    if (windKmh != null && windKmh > 35.0) {
      recommendedSpeed -= 10;
      reasons.add('Viaduct crosswinds of ${windKmh.toStringAsFixed(0)} km/h');
    }

    // 3. Traffic Deductions
    if (delayMinutes >= 15) {
      recommendedSpeed = (recommendedSpeed > 40) ? 35 : recommendedSpeed;
      reasons.add('Live TomTom congestion (+${delayMinutes}m delay) - traffic crawling at $speedText');
    } else if (delayMinutes >= 5) {
      recommendedSpeed -= 15;
      reasons.add('Moderate traffic queue (+${delayMinutes}m delay) near toll/choke point');
    }

    // 4. Night in Mountain Section
    if (isNight && (regCode == 'R4' || regCode == 'R5')) {
      recommendedSpeed -= 10;
      reasons.add('Night darkness on unlit mountain hairpin bends');
    }

    // 5. Clamping & Optimal Case
    if (recommendedSpeed < 30) recommendedSpeed = 30; // Minimum safe transit speed
    if (recommendedSpeed > statutorySpeed) recommendedSpeed = statutorySpeed;

    if (reasons.isEmpty) {
      if (statutorySpeed == 50) {
        reasons.add('Dry pavement & clear sightlines - maintain statutory 50 km/h mountain pass speed');
      } else {
        reasons.add('Optimal dry road conditions - maintain designated $statutorySpeed km/h cruising speed');
      }
    }

    return {
      'statutory_speed': statutorySpeed,
      'recommended_speed': recommendedSpeed,
      'is_reduced': recommendedSpeed < statutorySpeed,
      'reasons': reasons,
    };
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

    if (reasons.isEmpty && score != null && score < 80) {
      reasons.add('Moderate caution advised on this stretch ($score/100).');
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
    double? tempC;
    double? visKm;
    double? rainMm;
    double? windKmh;
    int? humidityVal;
    bool isRain = false;

    if (weather is Map) {
      cond = weather['weather_condition']?.toString() ?? 'Clear';
      final temp = weather['temperature_c'];
      if (temp != null) {
        tempC = (temp is num) ? temp.toDouble() : double.tryParse(temp.toString());
      }
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
      final rawRc = (weather['rain_condition'] ?? weather['rain'])?.toString().trim().toLowerCase();
      final bool hasRainCond = rawRc != null &&
          rawRc.isNotEmpty &&
          rawRc != 'no rain' &&
          rawRc != 'none' &&
          rawRc != 'clear' &&
          rawRc != 'nil' &&
          rawRc != '0' &&
          rawRc != 'dry' &&
          (rawRc.contains('rain') || rawRc.contains('drizzle') || rawRc.contains('shower') || rawRc.contains('storm') || rawRc.contains('monsoon'));
      final bool hasRainMm = rainMm != null && rainMm > 0.0;
      isRain = hasRainCond || hasRainMm;
      if (isRain) {
        precipitationStr = hasRainMm ? '${rainMm.toStringAsFixed(1)} mm Rain' : (weather['rain_condition'] ?? weather['rain'] ?? 'Rain Expected').toString();
        roadGripStr = 'Damp Road Surface';
      } else {
        precipitationStr = 'No Rain Forecast';
        roadGripStr = 'Dry Road Surface';
      }

      final ws = weather['wind_speed_kmh'];
      if (ws != null && ws is num) {
        windKmh = ws.toDouble();
      }
    }

    // Detect night travel (19:00 to 06:00 IST)
    bool isNight = false;
    if (isPlanner && travelTime != null && travelTime.isNotEmpty) {
      final hourMatch = RegExp(r'(\d{1,2})').firstMatch(travelTime);
      if (hourMatch != null) {
        int hr = int.tryParse(hourMatch.group(1) ?? '12') ?? 12;
        final tLower = travelTime.toLowerCase();
        if (tLower.contains('pm') && hr < 12) hr += 12;
        if (tLower.contains('am') && hr == 12) hr = 0;
        isNight = (hr >= 19 || hr < 6);
      }
    } else {
      final nowHr = DateTime.now().hour;
      isNight = (nowHr >= 19 || nowHr < 6);
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
              !s.contains('terrain geometry') &&
              !s.contains('smooth') &&
              !s.contains('dry') &&
              !s.contains('free flow') &&
              !s.contains('normal flow') &&
              !s.contains('no rain') &&
              !s.contains('no delay') &&
              !s.contains('safe');
        })
        .toList();

    // Parse TomTom live traffic delay
    int delayMinutes = 0;
    if (liveTraffic is Map && liveTraffic['delay_minutes'] is num) {
      delayMinutes = (liveTraffic['delay_minutes'] as num).toInt();
    }

    final int sVal = score ?? 90;

    // Dynamically compute safe speed based on sector statutory limit + rain + visibility + traffic crawl
    final dynamicSpeedData = _computeDynamicSafeSpeed(
      regCode: regCode,
      safeSpeedAdv: segment['safe_speed_advisory'],
      isRain: isRain,
      rainMm: rainMm,
      precipitationStr: precipitationStr,
      isNight: isNight,
      visKm: visKm,
      windKmh: windKmh,
      delayMinutes: delayMinutes,
      speedText: speedText,
    );
    final int statutorySpeed = dynamicSpeedData['statutory_speed'] as int;
    final int recommendedSpeed = dynamicSpeedData['recommended_speed'] as int;
    final bool isSpeedReduced = dynamicSpeedData['is_reduced'] as bool;
    final List<String> speedReasons = (dynamicSpeedData['reasons'] as List).map((e) => e.toString()).toList();

    // Dynamically generate safety assessment quoting exact weather & traffic telemetry
    final String conditionAssessment = _buildDynamicSafetyAssessment(
      code: regCode,
      sVal: sVal,
      title: title,
      isRain: isRain,
      rainMm: rainMm,
      precipitationStr: precipitationStr,
      isNight: isNight,
      visKm: visKm,
      windKmh: windKmh,
      tempC: tempC,
      delayMinutes: delayMinutes,
      speedText: speedText,
      statutorySpeed: statutorySpeed,
      recommendedSpeed: recommendedSpeed,
      isPlanner: isPlanner,
      travelDate: travelDate,
      travelTime: travelTime,
    );

    // Dynamically generate area driving advisory tailored to sector terrain + weather + traffic
    final String sectorAdvisory = _buildDynamicAreaAdvisory(
      code: regCode,
      title: title,
      isRain: isRain,
      rainMm: rainMm,
      precipitationStr: precipitationStr,
      isNight: isNight,
      visKm: visKm,
      windKmh: windKmh,
      tempC: tempC,
      delayMinutes: delayMinutes,
      speedText: speedText,
      statutorySpeed: statutorySpeed,
      recommendedSpeed: recommendedSpeed,
    );

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

                      // Dynamic Safety Assessment & Outlook Card (styled by score & risk)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sVal >= 75
                              ? const Color(0xFFF0FDF4)
                              : (sVal >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sVal >= 75
                                ? const Color(0xFFBBF7D0)
                                : (sVal >= 60 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  sVal >= 75
                                      ? Icons.shield_rounded
                                      : (sVal >= 60 ? Icons.info_outline_rounded : Icons.warning_amber_rounded),
                                  size: 14,
                                  color: sVal >= 75
                                      ? const Color(0xFF16A34A)
                                      : (sVal >= 60 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Safety Assessment & Outlook • ${sVal >= 85 ? 'Optimal' : (sVal >= 75 ? 'Good' : (sVal >= 60 ? 'Caution Advised' : 'Active Hazard'))}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: sVal >= 75
                                        ? const Color(0xFF15803D)
                                        : (sVal >= 60 ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              conditionAssessment,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppTheme.darkNavy.withValues(alpha: 0.9),
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

                      // Active Hazards Warning (strictly genuine hazards when conditions are degraded < 80)
                      if (cleanRisks.isNotEmpty && sVal < 80) ...[
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
    if (score < 70) return 'Caution';
    if (score < 85) return 'Safe';
    return 'Optimal';
  }

  String _getOverallVerdict(int score) {
    if (score < 45) return 'Hazardous conditions detected. Caution strongly advised.';
    if (score < 70) return 'Moderate adverse weather or traffic. Drive with extra care.';
    if (score < 85) return 'Safe highway conditions with standard travel precautions.';
    return 'Optimal travel conditions with clear roads and fluid traffic flow.';
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

/// Sector geographical and topographical physical profile for dynamic calculations
class _SectorGeoProfile {
  final int baseElevM;
  final int peakElevM;
  final double gradientPct;
  final String terrainDesc;
  final String keyFeature;

  const _SectorGeoProfile({
    required this.baseElevM,
    required this.peakElevM,
    required this.gradientPct,
    required this.terrainDesc,
    required this.keyFeature,
  });
}