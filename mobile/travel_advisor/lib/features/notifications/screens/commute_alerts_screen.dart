import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/services/commute_habit_service.dart';

/// Clean, simple, and intuitive Daily Travel Alerts screen.
/// Designed with easy English so any commuter, cab driver, or elder can use it effortlessly.
class CommuteAlertsScreen extends StatefulWidget {
  const CommuteAlertsScreen({super.key});

  @override
  State<CommuteAlertsScreen> createState() => _CommuteAlertsScreenState();
}

class _CommuteAlertsScreenState extends State<CommuteAlertsScreen> {
  final CommuteHabitService _habitService = CommuteHabitService();
  bool _isLoading = false;
  bool _isSaving = false;

  // Form State
  String _source = 'Panvel';
  String _destination = 'Pune';
  TimeOfDay _depTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _alertTime = const TimeOfDay(hour: 7, minute: 45);
  Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  bool _isEnabled = true;

  static const List<String> _corridorPoints = [
    'Mumbai',
    'Panvel',
    'Khalapur',
    'Khopoli',
    'Khandala',
    'Lonavala',
    'Kamshet',
    'Pune',
  ];

  static const List<_DayItem> _daysList = [
    _DayItem('Mon', 'M', 'Monday'),
    _DayItem('Tue', 'T', 'Tuesday'),
    _DayItem('Wed', 'W', 'Wednesday'),
    _DayItem('Thu', 'T', 'Thursday'),
    _DayItem('Fri', 'F', 'Friday'),
    _DayItem('Sat', 'S', 'Saturday'),
    _DayItem('Sun', 'S', 'Sunday'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _habitService.loadHabit();

    final habit = _habitService.commuteHabitNotifier.value;
    if (habit != null) {
      _applyHabitToState(habit);
    }

    if (_habitService.activeAlertNotifier.value == null) {
      await _habitService.fetchAlert(source: _source, destination: _destination);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyHabitToState(Map<String, dynamic> habit) {
    final src = habit['source']?.toString() ?? 'Panvel';
    final dst = habit['destination']?.toString() ?? 'Pune';
    final dep = habit['departure_time']?.toString() ?? '08:00 AM';
    final alert = habit['alert_time']?.toString() ?? '07:45 AM';
    final rawDays = habit['travel_days']?.toString() ?? 'Mon-Fri';
    final enabled = habit['is_enabled'] != false;

    _source = _corridorPoints.contains(src) ? src : 'Panvel';
    _destination = _corridorPoints.contains(dst) ? dst : 'Pune';
    _depTime = CommuteHabitService.parseTime(dep);
    _alertTime = CommuteHabitService.parseTime(alert);
    _isEnabled = enabled;

    if (rawDays == 'Daily' || rawDays == 'Everyday') {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
    } else if (rawDays == 'Sat-Sun' || rawDays == 'Weekends') {
      _selectedDays = {'Sat', 'Sun'};
    } else if (rawDays == 'Mon-Fri' || rawDays == 'Weekdays') {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
    } else {
      final clean = rawDays.replaceFirst('Custom:', '');
      final parts = clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      _selectedDays = parts.isNotEmpty ? parts.toSet() : {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);

    final String formattedDep = CommuteHabitService.formatTime12h(_depTime);
    final String formattedAlert = CommuteHabitService.formatTime12h(_alertTime);

    String travelDaysStr;
    if (_selectedDays.length == 7) {
      travelDaysStr = 'Daily';
    } else if (_selectedDays.length == 2 &&
        _selectedDays.contains('Sat') &&
        _selectedDays.contains('Sun')) {
      travelDaysStr = 'Sat-Sun';
    } else if (_selectedDays.length == 5 &&
        !_selectedDays.contains('Sat') &&
        !_selectedDays.contains('Sun')) {
      travelDaysStr = 'Mon-Fri';
    } else {
      const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sorted = order.where((d) => _selectedDays.contains(d)).toList();
      travelDaysStr = sorted.join(',');
    }

    await _habitService.saveHabit(
      source: _source,
      destination: _destination,
      departureTime: formattedDep,
      alertTime: formattedAlert,
      travelDays: travelDaysStr,
      isEnabled: _isEnabled,
    );

    await _habitService.fetchAlert(source: _source, destination: _destination);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily travel alerts saved! You will receive updates 15 mins before leaving.'),
          backgroundColor: Color(0xFF1D4ED8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _swapDirection() {
    setState(() {
      final temp = _source;
      _source = _destination;
      _destination = temp;
    });
  }

  void _setPresetDays(String preset) {
    setState(() {
      if (preset == 'weekdays') {
        _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
      } else if (preset == 'daily') {
        _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
      } else if (preset == 'weekends') {
        _selectedDays = {'Sat', 'Sun'};
      }
    });
  }

  void _toggleDay(String code) {
    setState(() {
      if (_selectedDays.contains(code)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(code);
        }
      } else {
        _selectedDays.add(code);
      }
    });
  }

  Future<void> _pickDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _depTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D4ED8),
              onPrimary: Colors.white,
              onSurface: AppTheme.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _depTime = picked;
        // Auto-calculate alert notice 15 minutes before
        final totalMin = picked.hour * 60 + picked.minute;
        final alertTotal = (totalMin - 15) % 1440;
        _alertTime = TimeOfDay(hour: (alertTotal ~/ 60), minute: (alertTotal % 60));
      });
    }
  }

  Future<void> _pickAlertTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _alertTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              onSurface: AppTheme.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _alertTime = picked;
      });
    }
  }

  String _getDaysSummaryText() {
    if (_selectedDays.length == 7) return 'Alerts will arrive everyday before departure';
    if (_selectedDays.length == 5 &&
        !_selectedDays.contains('Sat') &&
        !_selectedDays.contains('Sun')) {
      return 'Alerts will arrive on weekdays (Monday to Friday)';
    }
    if (_selectedDays.length == 2 &&
        _selectedDays.contains('Sat') &&
        _selectedDays.contains('Sun')) {
      return 'Alerts will arrive on weekends (Saturday & Sunday)';
    }
    return 'Alerts active on ${_selectedDays.length} selected days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Travel Alerts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            Text(
              'Automatic road & weather alerts before you leave',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.darkNavy),
            tooltip: 'Refresh Status',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // 1. TODAY'S ROAD STATUS
                _buildLiveStatusCard(),

                const SizedBox(height: 16),

                // 2. YOUR TRAVEL ROUTE
                _buildRouteSection(),

                const SizedBox(height: 16),

                // 3. TRAVEL TIMINGS
                _buildTimeSection(),

                const SizedBox(height: 16),

                // 4. DAYS YOU TRAVEL
                _buildDaysSection(),

                const SizedBox(height: 16),

                // 5. AUTOMATIC NOTIFICATIONS TOGGLE
                _buildNotificationToggleCard(),

                const SizedBox(height: 24),

                // 6. SAVE & VERIFY ACTIONS
                _buildActionButtons(),
              ],
            ),
    );
  }

  // ============================================================
  // CLEAN & SIMPLE WIDGETS
  // ============================================================

  Widget _buildLiveStatusCard() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _habitService.activeAlertNotifier,
      builder: (context, alert, child) {
        if (alert == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expressway is Clear • $_source ➔ $_destination',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'No road closures, bad weather, or heavy delays reported.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final int score = (alert['safety_score'] as num?)?.toInt() ?? 70;
        final String risk = alert['risk_level'] ?? 'Normal';
        final List warnings = (alert['warnings'] as List?) ?? [];
        final Color accentColor = score < 60
            ? const Color(0xFFDC2626)
            : (score < 80 ? const Color(0xFFD97706) : const Color(0xFF059669));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SAFETY SCORE: $score/100 • $risk',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_source ➔ $_destination',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final w in warnings.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            w.toString(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.darkNavy,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'YOUR TRAVEL ROUTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_source ➔ $_destination',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Origin / Source Column with Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trip_origin_rounded, size: 12, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'SOURCE / FROM',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF065F46),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _source,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          items: _corridorPoints.map((pt) {
                            return DropdownMenuItem(
                              value: pt,
                              child: Text(
                                pt,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkNavy,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _source = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow and Swap Button in Middle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 18), // Align with dropdowns
                    Tooltip(
                      message: 'Swap Route Direction',
                      child: InkWell(
                        onTap: _swapDirection,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF1D4ED8),
                                size: 16,
                              ),
                              SizedBox(width: 3),
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFF1D4ED8),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Destination Column with Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'DESTINATION / TO',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF991B1B),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _destination,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          items: _corridorPoints.map((pt) {
                            return DropdownMenuItem(
                              value: pt,
                              child: Text(
                                pt,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkNavy,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _destination = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSection() {
    return Row(
      children: [
        // Departure Time Card
        Expanded(
          child: InkWell(
            onTap: _pickDepartureTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 5),
                      Text(
                        'DEPARTURE TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CommuteHabitService.formatTime12h(_depTime),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to set time',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Alert Notice Time Card
        Expanded(
          child: InkWell(
            onTap: _pickAlertTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 5),
                      Text(
                        'ALERT NOTICE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CommuteHabitService.formatTime12h(_alertTime),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '15 min prior alert',
                    style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'DAYS YOU TRAVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedDays.length} days active',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Chips Row
          Row(
            children: [
              _buildPresetChip('Weekdays (Mon-Fri)', 'weekdays'),
              const SizedBox(width: 6),
              _buildPresetChip('Everyday', 'daily'),
              const SizedBox(width: 6),
              _buildPresetChip('Weekends', 'weekends'),
            ],
          ),

          const SizedBox(height: 12),

          // 7-Day Circular Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _daysList.map((day) {
              final isSelected = _selectedDays.contains(day.code);
              return InkWell(
                onTap: () => _toggleDay(day.code),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    day.initial,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),
          Text(
            _getDaysSummaryText(),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String presetKey) {
    bool isSelected = false;
    if (presetKey == 'weekdays') {
      isSelected = _selectedDays.length == 5 &&
          !_selectedDays.contains('Sat') &&
          !_selectedDays.contains('Sun');
    } else if (presetKey == 'daily') {
      isSelected = _selectedDays.length == 7;
    } else if (presetKey == 'weekends') {
      isSelected = _selectedDays.length == 2 &&
          _selectedDays.contains('Sat') &&
          _selectedDays.contains('Sun');
    }

    return InkWell(
      onTap: () => _setPresetDays(presetKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggleCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 18,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Departure Alerts',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Checks rain, fog, and road conditions before you travel',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isEnabled,
            activeThumbColor: const Color(0xFF1D4ED8),
            onChanged: (val) {
              setState(() => _isEnabled = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Travel Alert Settings',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking road conditions for your route...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final alert = await _habitService.triggerTestAlert(
                source: _source,
                destination: _destination,
              );
              if (mounted && alert != null) {
                final score = alert['safety_score'] ?? 80;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Test Notification Sent: Score $score/100 (${alert['risk_level'] ?? 'Normal'})',
                    ),
                    backgroundColor: const Color(0xFF1D4ED8),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 15, color: Color(0xFF64748B)),
            label: const Text(
              'Send Test Alert Notification',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayItem {
  final String code;
  final String initial;
  final String fullName;

  const _DayItem(this.code, this.initial, this.fullName);
}
