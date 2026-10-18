import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../analysis/screens/journey_analysis_screen.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final int userId = (await ApiService.getStoredUserId()) ?? 1;
      final List<Map<String, dynamic>> fetched =
          await ApiService.getSavedReports(userId: userId);

      if (!mounted) return;

      setState(() {
        _reports = fetched.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load saved reports. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Color _getScoreColor(int score) {
    return SafetyMeterPainter.getScoreColor(score);
  }

  Future<void> _openReport(Map<String, dynamic> summary) async {
    final int? reportId = summary['id'] is num ? (summary['id'] as num).toInt() : null;
    if (reportId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final int userId = (await ApiService.getStoredUserId()) ?? 1;
      final Map<String, dynamic> detail = await ApiService.getSavedReport(
        userId: userId,
        reportId: reportId,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      final dynamic analysisData = detail['analysis_data'] ?? summary['analysis_data'];
      String title = summary['title']?.toString() ?? 'Travel Report';
      String source = summary['source']?.toString() ?? detail['source']?.toString() ?? 'Mumbai';
      String destination = summary['destination']?.toString() ?? detail['destination']?.toString() ?? 'Pune';
      String role = summary['role']?.toString() ?? detail['role']?.toString() ?? 'traveler';

      if ((summary['source'] == null || summary['source'].toString().isEmpty) && title.contains('→')) {
        final parts = title.split('→');
        source = parts[0].replaceAll('Travel Report', '').trim();
        destination = parts[1].replaceAll('Travel Report', '').trim();
      }

      Navigator.pushNamed(
        context,
        AppRoutes.journeyAnalysis,
        arguments: {
          'analysis': analysisData,
          'source': source,
          'destination': destination,
          'role': role,
          'isSavedReport': true,
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the full report.')),
      );
    }
  }

  Future<void> _deleteReport(int reportId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Do you want to remove this saved travel report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final int userId = (await ApiService.getStoredUserId()) ?? 1;
      await ApiService.deleteSavedReport(userId: userId, reportId: reportId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Travel report deleted successfully.')),
      );
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete report.')),
      );
    }
  }

  String _formatDate(dynamic dateRaw) {
    if (dateRaw == null) return '';
    try {
      final String raw = dateRaw.toString().trim();
      DateTime dt;
      if (!raw.contains('+') && !raw.endsWith('Z') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(raw)) {
        dt = DateTime.parse('$raw+05:30').toUtc().add(const Duration(hours: 5, minutes: 30));
      } else {
        dt = DateTime.parse(raw).toUtc().add(const Duration(hours: 5, minutes: 30));
      }
      final String month = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][dt.month - 1];
      final String hour = dt.hour.toString().padLeft(2, '0');
      final String minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $month ${dt.year}, $hour:$minute';
    } catch (_) {
      return dateRaw.toString();
    }
  }

  String _getRiskLabel(int score) {
    if (score < 45) return 'High Risk';
    if (score < 65) return 'Caution';
    if (score < 85) return 'Moderate';
    return 'Safe';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Saved Travel Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            if (!_isLoading && _reports.isNotEmpty)
              Text(
                '${_reports.length} ${_reports.length == 1 ? "report" : "reports"} archived',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReports,
          color: const Color(0xFF1D4ED8),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.forestGreen),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 54, color: AppTheme.textSecondary),
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadReports,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_reports.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      size: 38,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Saved Reports Yet',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Evaluate a corridor journey and tap "Save Report" to archive route risk conditions, telemetry, and forecasts here for quick reference.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x301D4ED8),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.roleSelection);
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Evaluate New Journey',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final item = _reports[index];
        final int reportId = item['id'] is num ? (item['id'] as num).toInt() : 0;
        final String title = item['title']?.toString() ?? 'Travel Report';
        final String dateStr = _formatDate(item['created_at']);
        final dynamic scoreVal = item['safety_score'] ?? item['overall_safety_score'];
        final int score = scoreVal is num ? scoreVal.round() : 0;
        final Color scoreColor = _getScoreColor(score);
        final String riskLabel = _getRiskLabel(score);
        final String role = item['role']?.toString().toLowerCase() ?? 'traveler';
        final bool isPlanner = role == 'planner';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.verified_user_rounded,
                                  color: scoreColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isPlanner ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isPlanner ? 'PLANNER' : 'TRAVELER',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isPlanner ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '$score • $riskLabel',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: scoreColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _openReport(item),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF1D4ED8)),
                                      SizedBox(width: 6),
                                      Text(
                                        'View Full Analysis',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 19),
                                onPressed: () => _deleteReport(reportId),
                                tooltip: 'Delete Report',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
