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
      final DateTime dt = DateTime.parse(dateRaw.toString()).toLocal();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Travel Reports',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReports,
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.lightMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      size: 36,
                      color: AppTheme.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Saved Reports Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete a journey evaluation and tap "Save Report" in the chat to review route conditions whenever needed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final item = _reports[index];
        final int reportId = item['id'] is num ? (item['id'] as num).toInt() : 0;
        final String title = item['title']?.toString() ?? 'Travel Report';
        final String dateStr = _formatDate(item['created_at']);
        final dynamic scoreVal = item['safety_score'] ?? item['overall_safety_score'];
        final int score = scoreVal is num ? scoreVal.round() : 0;
        final Color scoreColor = _getScoreColor(score);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: scoreColor,
                        size: 24,
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
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Score: $score',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openReport(item),
                      icon: const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.forestGreen),
                      label: const Text(
                        'View Analysis',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                      onPressed: () => _deleteReport(reportId),
                      tooltip: 'Delete Report',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
