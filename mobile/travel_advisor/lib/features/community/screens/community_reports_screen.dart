import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';

class CommunityReportsScreen extends StatefulWidget {
  const CommunityReportsScreen({super.key});

  @override
  State<CommunityReportsScreen> createState() =>
      _CommunityReportsScreenState();
}

class _CommunityReportsScreenState
    extends State<CommunityReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _riskyRegions = [];
  String _selectedFilter = 'All';

  static const List<Map<String, String>> _corridorSegments = [
    {'code': 'R1', 'name': 'Mumbai to Panvel'},
    {'code': 'R2', 'name': 'Panvel to Khalapur'},
    {'code': 'R3', 'code_alt': 'R3', 'name': 'Khalapur to Khopoli'},
    {'code': 'R4', 'name': 'Khopoli to Khandala (Bhor Ghat)'},
    {'code': 'R5', 'name': 'Khandala to Lonavala'},
    {'code': 'R6', 'name': 'Lonavala to Kamshet'},
    {'code': 'R7', 'name': 'Kamshet to Pune'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveReports();
  }

  Future<void> _loadLiveReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getLiveCommunityReports(hours: 6);

      if (!mounted) return;

      final rawReports = (data['reports'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final rawRisky = (data['risky_regions'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      setState(() {
        _reports = rawReports;
        _riskyRegions = rawRisky;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to fetch live road updates. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_selectedFilter == 'Risky Only') {
      return _reports.where((r) => r['is_risky'] == true).toList();
    }
    if (_selectedFilter == 'Low Visibility') {
      return _reports.where((r) {
        final vis = (r['visibility'] ?? '').toString().toLowerCase();
        return vis.contains('fog') ||
            vis.contains('mist') ||
            vis.contains('zero') ||
            vis.contains('< 200m');
      }).toList();
    }
    if (_selectedFilter == 'Rainfall') {
      return _reports.where((r) {
        final rain = (r['rain'] ?? '').toString().toLowerCase();
        return rain.contains('downpour') ||
            rain.contains('moderate') ||
            rain.contains('drizzle') ||
            rain.contains('heavy');
      }).toList();
    }
    if (_selectedFilter == 'Traffic') {
      return _reports.where((r) {
        final trf = (r['traffic'] ?? '').toString().toLowerCase();
        return trf.contains('congestion') ||
            trf.contains('standstill') ||
            trf.contains('delay');
      }).toList();
    }
    return _reports;
  }

  String _formatAge(dynamic minutes) {
    if (minutes == null) return 'recently';
    final int m = (minutes as num).toInt();
    if (m < 1) return 'Just now';
    if (m < 60) return '$m min ago';
    final int hours = m ~/ 60;
    final int rem = m % 60;
    if (rem == 0) return '$hours hr ago';
    return '${hours}h ${rem}m ago';
  }

  String _formatExpires(dynamic minutes) {
    if (minutes == null) return 'Active';
    final int m = (minutes as num).toInt();
    if (m <= 0) return 'Expiring';
    if (m < 60) return 'Expires in $m m';
    final int hours = m ~/ 60;
    final int rem = m % 60;
    return 'Active for ${hours}h ${rem}m';
  }

  void _showSubmitModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubmitRoadReportSheet(
        corridorSegments: _corridorSegments,
        onSubmitted: () {
          _loadLiveReports();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightMint,
      appBar: AppBar(
        backgroundColor: AppTheme.lightMint,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Live Road Updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            Text(
              'Community corridor feed • Active 6 hours',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.darkNavy,
            ),
            tooltip: 'Refresh',
            onPressed: _loadLiveReports,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Report Road Condition',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        onPressed: _showSubmitModal,
      ),
      body: RefreshIndicator(
        color: AppTheme.forestGreen,
        onRefresh: _loadLiveReports,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.forestGreen,
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.forestGreen,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _loadLiveReports,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    children: [
                      _buildRiskyRegionsHeader(),
                      const SizedBox(height: 16),
                      _buildFilterChips(),
                      const SizedBox(height: 16),
                      _buildReportsList(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRiskyRegionsHeader() {
    if (_riskyRegions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF22C55E).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Corridor Normal & Clear',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'No severe hazards or low visibility reported by travelers in the past 6 hours.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 20,
            ),
            const SizedBox(width: 6),
            const Text(
              'Active Risky Corridor Segments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_riskyRegions.length} FLAGGED',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._riskyRegions.map((risk) => _buildRiskSegmentCard(risk)),
      ],
    );
  }

  Widget _buildRiskSegmentCard(Map<String, dynamic> risk) {
    final bool isHigh = risk['risk_level'] == 'High Risk';
    final Color badgeColor =
        isHigh ? const Color(0xFFDC2626) : const Color(0xFFEA580C);

    final List<dynamic> issues = (risk['issues'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  risk['risk_level']?.toString().toUpperCase() ?? 'RISK',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  risk['segment_name']?.toString() ?? 'Highway Segment',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${risk['report_count'] ?? 1} reports',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            risk['summary']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkNavy,
              height: 1.35,
            ),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: issues.map((issue) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    issue.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      'All',
      'Risky Only',
      'Low Visibility',
      'Rainfall',
      'Traffic',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                f == 'All' ? 'All (${_reports.length})' : f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.darkNavy,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.darkNavy,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.darkNavy
                      : Colors.grey.shade300,
                ),
              ),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = f;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportsList() {
    final list = _filteredReports;

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No Road Updates in This Category',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reports automatically clear after 6 hours. Be the first to post current highway conditions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.forestGreen,
                side: const BorderSide(color: AppTheme.forestGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Road Update'),
              onPressed: _showSubmitModal,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Community Feed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            Text(
              '${list.length} active updates',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...list.map((report) => _buildReportCard(report)),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final bool isRisky = report['is_risky'] == true;
    final String regionName =
        report['region_name']?.toString() ?? 'Corridor Segment';
    final String ageStr = _formatAge(report['age_minutes']);
    final String expiresStr = _formatExpires(report['expires_in_minutes']);

    final String? vis = report['visibility']?.toString();
    final String? rain = report['rain']?.toString();
    final String? road = report['road_condition']?.toString();
    final String? traffic = report['traffic']?.toString();

    final bool lowVis = (vis ?? '').toLowerCase().contains('fog') ||
        (vis ?? '').toLowerCase().contains('mist') ||
        (vis ?? '').toLowerCase().contains('zero') ||
        (vis ?? '').toLowerCase().contains('< 200m');

    final bool severeRoad = (road ?? '').toLowerCase().contains('landslide') ||
        (road ?? '').toLowerCase().contains('waterlog') ||
        (road ?? '').toLowerCase().contains('pothole') ||
        (road ?? '').toLowerCase().contains('slippery');

    final bool heavyRain = (rain ?? '').toLowerCase().contains('heavy') ||
        (rain ?? '').toLowerCase().contains('downpour');

    final bool highTraffic =
        (traffic ?? '').toLowerCase().contains('standstill') ||
            (traffic ?? '').toLowerCase().contains('congestion');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRisky
              ? const Color(0xFFDC2626).withOpacity(0.25)
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isRisky
                      ? const Color(0xFFDC2626).withOpacity(0.1)
                      : AppTheme.forestGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRisky
                      ? Icons.warning_rounded
                      : Icons.fmd_good_rounded,
                  size: 16,
                  color: isRisky
                      ? const Color(0xFFDC2626)
                      : AppTheme.forestGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  regionName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              Text(
                ageStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  expiresStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (vis != null && vis.isNotEmpty)
                _buildMetricPill(
                  icon: Icons.visibility_rounded,
                  label: 'Vis: $vis',
                  isWarning: lowVis,
                  color: lowVis
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
              if (rain != null && rain.isNotEmpty)
                _buildMetricPill(
                  icon: Icons.water_drop_rounded,
                  label: 'Rain: $rain',
                  isWarning: heavyRain,
                  color: heavyRain
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF16A34A),
                ),
              if (road != null && road.isNotEmpty)
                _buildMetricPill(
                  icon: Icons.alt_route_rounded,
                  label: 'Road: $road',
                  isWarning: severeRoad,
                  color: severeRoad
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF16A34A),
                ),
              if (traffic != null && traffic.isNotEmpty)
                _buildMetricPill(
                  icon: Icons.traffic_rounded,
                  label: 'Traffic: $traffic',
                  isWarning: highTraffic,
                  color: highTraffic
                      ? const Color(0xFFD97706)
                      : const Color(0xFF16A34A),
                ),
            ],
          ),
          if (report['raw_message'] != null &&
              report['raw_message'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                '“${report['raw_message']}”',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.darkNavy,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required bool isWarning,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SUBMIT REPORT BOTTOM SHEET MODAL
// ================================================================

class _SubmitRoadReportSheet extends StatefulWidget {
  final List<Map<String, String>> corridorSegments;
  final VoidCallback onSubmitted;

  const _SubmitRoadReportSheet({
    required this.corridorSegments,
    required this.onSubmitted,
  });

  @override
  State<_SubmitRoadReportSheet> createState() => _SubmitRoadReportSheetState();
}

class _SubmitRoadReportSheetState extends State<_SubmitRoadReportSheet> {
  String? _selectedSegmentCode;
  String _selectedVisibility = 'Clear (> 1 km)';
  String _selectedRain = 'None';
  String _selectedRoadCondition = 'Smooth / Dry';
  String _selectedTraffic = 'Free flow';
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _visibilityOptions = [
    'Clear (> 1 km)',
    'Moderate mist (500m - 1km)',
    'Dense fog (< 200m)',
    'Near zero visibility',
  ];

  static const List<String> _rainOptions = [
    'None',
    'Light drizzle',
    'Moderate rain',
    'Heavy downpour',
  ];

  static const List<String> _roadOptions = [
    'Smooth / Dry',
    'Wet / Slippery',
    'Waterlogging',
    'Potholes',
    'Landslide / Rockfall',
  ];

  static const List<String> _trafficOptions = [
    'Free flow',
    'Moderate delay',
    'Heavy congestion',
    'Standstill',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSegmentCode = widget.corridorSegments[4]['code']; // Khandala - Lonavala
  }

  Future<void> _submit() async {
    if (_selectedSegmentCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route segment.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.submitCommunityReport(
        routeRegion: _selectedSegmentCode!,
        visibility: _selectedVisibility,
        rain: _selectedRain,
        roadCondition: _selectedRoadCondition,
        traffic: _selectedTraffic,
        rawMessage: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live road report posted! Active for 6 hours.'),
          backgroundColor: AppTheme.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post report: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Report Highway Condition',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your input will be visible to travelers and automatically expires after 6 hours.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'CORRIDOR SEGMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSegmentCode,
                  items: widget.corridorSegments.map((seg) {
                    return DropdownMenuItem<String>(
                      value: seg['code'],
                      child: Text(
                        '${seg['code']}: ${seg['name']}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSegmentCode = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChoiceGroup(
              title: 'VISIBILITY',
              options: _visibilityOptions,
              selected: _selectedVisibility,
              onSelected: (val) => setState(() => _selectedVisibility = val),
            ),
            const SizedBox(height: 14),
            _buildChoiceGroup(
              title: 'RAINFALL',
              options: _rainOptions,
              selected: _selectedRain,
              onSelected: (val) => setState(() => _selectedRain = val),
            ),
            const SizedBox(height: 14),
            _buildChoiceGroup(
              title: 'ROAD CONDITION',
              options: _roadOptions,
              selected: _selectedRoadCondition,
              onSelected: (val) => setState(() => _selectedRoadCondition = val),
            ),
            const SizedBox(height: 14),
            _buildChoiceGroup(
              title: 'TRAFFIC FLOW',
              options: _trafficOptions,
              selected: _selectedTraffic,
              onSelected: (val) => setState(() => _selectedTraffic = val),
            ),
            const SizedBox(height: 16),
            const Text(
              'OPTIONAL NOTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Low visibility near expressway exit, drive slowly',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Post Road Update',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceGroup({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppTheme.darkNavy,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((opt) {
            final isSel = selected == opt;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppTheme.darkNavy
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel
                        ? AppTheme.darkNavy
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AppTheme.darkNavy,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
