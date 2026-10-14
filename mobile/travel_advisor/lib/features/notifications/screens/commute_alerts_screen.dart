import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/commute_habit_service.dart';

class CommuteAlertsScreen extends StatefulWidget {
  const CommuteAlertsScreen({super.key});

  @override
  State<CommuteAlertsScreen> createState() => _CommuteAlertsScreenState();
}

class _CommuteAlertsScreenState extends State<CommuteAlertsScreen> {
  final CommuteHabitService _habitService = CommuteHabitService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _habitService.loadHabit();
    if (_habitService.activeAlertNotifier.value == null) {
      await _habitService.fetchAlert();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _getScoreColor(int score) {
    if (score < 40) return AppTheme.crimsonRed;
    if (score < 60) return AppTheme.alertAmber;
    if (score < 75) return const Color(0xFFF59E0B);
    return AppTheme.forestGreen;
  }

  IconData _getWarningIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('visib') || lower.contains('fog')) {
      return Icons.cloud;
    }
    if (lower.contains('rain') || lower.contains('downpour')) {
      return Icons.water_drop;
    }
    if (lower.contains('road') || lower.contains('wet') || lower.contains('slippery')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('traffic') || lower.contains('congest')) {
      return Icons.traffic;
    }
    return Icons.report_problem;
  }

  void _showEditHabitDialog(Map<String, dynamic> habit) {
    String source = habit['source'] ?? 'Panvel';
    String destination = habit['destination'] ?? 'Pune';
    String departureTime = habit['departure_time'] ?? '08:00';
    String alertTime = habit['alert_time'] ?? '07:45';
    String travelDays = habit['travel_days'] ?? 'Mon-Fri';
    bool isEnabled = habit['is_enabled'] == true;

    final sourceCtrl = TextEditingController(text: source);
    final destCtrl = TextEditingController(text: destination);
    final depCtrl = TextEditingController(text: departureTime);
    final alertCtrl = TextEditingController(text: alertTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Configure Daily Commute Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: sourceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Starting Point',
                        prefixIcon: Icon(Icons.trip_origin, color: AppTheme.forestGreen),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: destCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.crimsonRed),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Active Commute Days',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Monday to Friday'),
                          selected: travelDays == 'Mon-Fri',
                          selectedColor: AppTheme.mint,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => travelDays = 'Mon-Fri');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Daily'),
                          selected: travelDays == 'Daily',
                          selectedColor: AppTheme.mint,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => travelDays = 'Daily');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Weekends'),
                          selected: travelDays == 'Sat-Sun',
                          selectedColor: AppTheme.mint,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => travelDays = 'Sat-Sun');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: depCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Departure (HH:MM IST)',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final parts = val.trim().split(':');
                              if (parts.length >= 2) {
                                final h = int.tryParse(parts[0]);
                                final m = int.tryParse(parts[1]);
                                if (h != null && m != null) {
                                  int totalMin = h * 60 + m - 15;
                                  if (totalMin < 0) totalMin += 1440;
                                  final alertH = (totalMin ~/ 60).toString().padLeft(2, '0');
                                  final alertM = (totalMin % 60).toString().padLeft(2, '0');
                                  setModalState(() {
                                    alertCtrl.text = '$alertH:$alertM';
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: alertCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Alert (HH:MM IST)',
                              prefixIcon: Icon(Icons.notifications_active),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Daily Proactive Alerts',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Automatically evaluates corridor safety prior to departure',
                      ),
                      value: isEnabled,
                      activeColor: AppTheme.forestGreen,
                      onChanged: (val) {
                        setModalState(() => isEnabled = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forestGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          await _habitService.saveHabit(
                            source: sourceCtrl.text.trim(),
                            destination: destCtrl.text.trim(),
                            departureTime: depCtrl.text.trim(),
                            alertTime: alertCtrl.text.trim(),
                            travelDays: travelDays,
                            isEnabled: isEnabled,
                          );
                          await _habitService.fetchAlert(
                            source: sourceCtrl.text.trim(),
                            destination: destCtrl.text.trim(),
                          );
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Commute alert schedule updated!'),
                                backgroundColor: AppTheme.forestGreen,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Save Commute Schedule',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightMint,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commute Alerts & Habits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Habit-based Corridor Intelligence',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Alert Assessment',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.forestGreen),
                  SizedBox(height: 12),
                  Text(
                    'Evaluating corridor safety & habits...',
                    style: TextStyle(color: AppTheme.subtleGrey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.forestGreen,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildActiveAlertSection(),
                  const SizedBox(height: 20),
                  _buildHabitScheduleSection(),
                  const SizedBox(height: 20),
                  _buildSimulationSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveAlertSection() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _habitService.activeAlertNotifier,
      builder: (context, alert, child) {
        if (alert == null) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.forestGreen, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Corridor Normal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'No active hazard alerts along your usual route.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _habitService.triggerTestAlert(),
                  child: const Text('Check Now'),
                ),
              ],
            ),
          );
        }

        final int score = (alert['safety_score'] as num?)?.toInt() ?? 70;
        final String riskLevel = alert['risk_level'] ?? 'Moderate';
        final Color scoreColor = _getScoreColor(score);
        final List warnings = (alert['warnings'] as List?) ?? [];
        final String title = alert['alert_title'] ?? 'Commute Alert';
        final String body = alert['alert_body'] ?? '';
        final String advice = alert['advice'] ?? '';
        final String src = alert['source'] ?? 'Panvel';
        final String dst = alert['destination'] ?? 'Pune';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: scoreColor.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scoreColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$src ➔ $dst',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          Text(
                            'Daily Pre-trip Assessment',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        riskLevel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score Gauge Row
                    Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scoreColor, width: 4),
                            color: scoreColor.withOpacity(0.08),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scoreColor.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (warnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Specific Regional Warnings:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...warnings.map((w) {
                        final icon = _getWarningIcon(w.toString());
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 18, color: scoreColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.darkNavy,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (advice.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppTheme.darkNavy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                advice,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.darkNavy,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.timeline, size: 18),
                            label: const Text('Live Updates'),
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.forestGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.analytics_outlined, size: 18),
                            label: const Text('Start Analysis'),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.tripDetails,
                                arguments: {
                                  'role': 'planner',
                                  'source': src,
                                  'destination': dst,
                                },
                              );
                            },
                          ),
                        ),
                      ],
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

  String _formatTravelDays(String? days) {
    if (days == 'Daily') return 'Daily (All 7 Days)';
    if (days == 'Sat-Sun') return 'Weekends (Sat & Sun)';
    return 'Monday to Friday (Commute Days)';
  }

  Widget _buildHabitScheduleSection() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _habitService.commuteHabitNotifier,
      builder: (context, habit, child) {
        final habitData = habit ?? {
          'source': 'Panvel',
          'destination': 'Pune',
          'departure_time': '08:00',
          'observed_check_time': '07:50',
          'alert_time': '07:45',
          'travel_days': 'Mon-Fri',
          'is_enabled': true,
        };

        final String src = habitData['source'] ?? 'Panvel';
        final String dst = habitData['destination'] ?? 'Pune';
        final String depTime = habitData['departure_time'] ?? '08:00';
        final String alertTime = habitData['alert_time'] ?? '07:45';
        final String travelDays = habitData['travel_days'] ?? 'Mon-Fri';
        final bool isEnabled = habitData['is_enabled'] == true;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.directions_car_filled, color: AppTheme.forestGreen, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Daily Commute Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.forestGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Configure'),
                    onPressed: () => _showEditHabitDialog(habitData),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Specify your daily route corridor, active commute days, departure time, and proactive alert schedule.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
              ),
              const SizedBox(height: 16),

              // Habit summary metrics
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.forestGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildHabitRow(
                      icon: Icons.directions_car,
                      label: 'Commute Corridor',
                      value: '$src ➔ $dst',
                    ),
                    const Divider(height: 16),
                    _buildHabitRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Active Days',
                      value: _formatTravelDays(travelDays),
                    ),
                    const Divider(height: 16),
                    _buildHabitRow(
                      icon: Icons.departure_board,
                      label: 'Departure Time',
                      value: '$depTime IST',
                    ),
                    const Divider(height: 16),
                    _buildHabitRow(
                      icon: Icons.alarm,
                      label: 'Proactive Alert Time',
                      value: '$alertTime IST (15 min prior)',
                      highlight: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daily Commute Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Switch(
                    value: isEnabled,
                    activeColor: AppTheme.forestGreen,
                    onChanged: (val) async {
                      await _habitService.saveHabit(
                        source: src,
                        destination: dst,
                        departureTime: depTime,
                        alertTime: alertTime,
                        travelDays: travelDays,
                        isEnabled: val,
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: highlight ? AppTheme.forestGreen : Colors.grey.shade700),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? AppTheme.forestGreen : AppTheme.darkNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildSimulationSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppTheme.forestGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Verify Notification Assessment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simulate and verify the proactive commute alert generated by our prediction model, live weather, and human community reports along your route.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text(
                'Verify Notification Alert',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                setState(() => _isLoading = true);
                final alert = await _habitService.triggerTestAlert();
                setState(() => _isLoading = false);

                if (mounted && alert != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Notification evaluated: Score ${alert['safety_score']}/100 • ${alert['risk_level']}',
                      ),
                      backgroundColor: _getScoreColor(alert['safety_score'] ?? 70),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
