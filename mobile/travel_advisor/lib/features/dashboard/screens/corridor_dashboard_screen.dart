import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/custom_corridor_icons.dart';

class CorridorDashboardScreen extends StatefulWidget {
  const CorridorDashboardScreen({super.key});

  @override
  State<CorridorDashboardScreen> createState() =>
      _CorridorDashboardScreenState();
}

class _CorridorDashboardScreenState extends State<CorridorDashboardScreen> {
  final CommuteHabitService _habitService = CommuteHabitService();

  bool _isLoggingOut = false;
  bool _isLoadingReports = false;
  bool _isTestingAlert = false;
  bool _isSavingSchedule = false;

  List<Map<String, dynamic>> _liveReportsPreview = [];

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

  // Active segmented tab index (0: Road Radar, 1: Commute Setup, 2: Saved Reports)
  int _selectedTabIndex = 0;

  // Selected expressway node in interactive corridor strip (Default: Bhor Ghat)
  int _selectedExpresswayNodeIndex = 4;

  // Dynamic corridor telemetry KPI state variables
  int _corridorSafetyScore = 96;
  String _corridorSafetyBadge = 'Optimal';
  String _ghatTemperature = '28°C';
  String _ghatCondition = 'Clear';
  String _corridorTrafficSummary = 'Free Flow';
  String _corridorTrafficBadge = 'Fluid';
  Color _corridorTrafficColor = const Color(0xFF10B981);

  static const List<Map<String, dynamic>> _defaultExpresswayNodes = [
    {
      'name': 'Mumbai',
      'code': 'BOM',
      'weather': '28°C Clear',
      'status': 'Normal Flow',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '60-80 km/h',
      'desc': 'Eastern Freeway & Mankhurd-Vashi flyover approaches. Normal metropolitan movement.',
    },
    {
      'name': 'Panvel',
      'code': 'PNV',
      'weather': '27°C Hazy',
      'status': 'Expressway Entry',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '80-100 km/h',
      'desc': 'NE-1 Expressway entry & Kalamboli junction. 6 wide asphalt lanes open.',
    },
    {
      'name': 'Khalapur',
      'code': 'KHL',
      'weather': '25°C Clear',
      'status': 'Toll Plaza',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '100 km/h',
      'desc': 'Khalapur toll gates & food plaza area. High-visibility open corridor stretch.',
    },
    {
      'name': 'Khopoli',
      'code': 'KHP',
      'weather': '23°C Cloudy',
      'status': 'Ghat Approach',
      'statusColor': Color(0xFFF59E0B),
      'speedAdvice': '60-70 km/h',
      'desc': 'Base of the Sahyadri mountains. Heavy vehicle lane discipline strictly monitored.',
    },
    {
      'name': 'Bhor Ghat',
      'code': 'GHT',
      'weather': '19°C Mist',
      'status': 'Mountain Sector',
      'statusColor': Color(0xFFF59E0B),
      'speedAdvice': '40-50 km/h',
      'desc': 'Steep gradient & hairpin curves. Maintain low gear and 50m braking distance.',
    },
    {
      'name': 'Lonavala',
      'code': 'LNV',
      'weather': '21°C Mild',
      'status': 'Plateau Section',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '70-80 km/h',
      'desc': 'Khandala viaduct & tunnel bypasses. Smooth asphalt surface and clear conditions.',
    },
    {
      'name': 'Kamshet',
      'code': 'KMS',
      'weather': '24°C Sunny',
      'status': 'Open Plains',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '90-100 km/h',
      'desc': 'Talegaon expressway run with twin tunnels. Free-flowing, unrestricted cruising.',
    },
    {
      'name': 'Pune',
      'code': 'PUN',
      'weather': '26°C Clear',
      'status': 'Corridor End',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '60-80 km/h',
      'desc': 'Expressway terminal at Kiwale / Dehu Road Bypass leading into Hinjewadi & Wakad.',
    },
  ];

  // Dynamic nodes list that is populated from OpenWeather & Google Maps traffic APIs
  late List<Map<String, dynamic>> _expresswayNodes = List.from(_defaultExpresswayNodes);

  Color _resolveStatusColor(dynamic val) {
    if (val is Color) return val;
    if (val is String) {
      final hex = val.replaceAll('#', '');
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
    return const Color(0xFF10B981);
  }

  // Selected commute schedule slot (0: Outbound Commute, 1: Return Commute)
  int _selectedScheduleSlot = 0;

  // Schedule Slot 0: Outbound (Morning Commute)
  String _outboundSource = 'Panvel';
  String _outboundDestination = 'Pune';
  TimeOfDay _outboundDepartureTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _outboundAlertTime = const TimeOfDay(hour: 7, minute: 45);
  String _outboundTravelDays = 'Daily';
  String _outboundDayMode = 'Daily';
  Set<String> _outboundCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  bool _outboundNotificationsEnabled = true;

  // Schedule Slot 1: Return (Evening Commute)
  String _returnSource = 'Pune';
  String _returnDestination = 'Panvel';
  TimeOfDay _returnDepartureTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _returnAlertTime = const TimeOfDay(hour: 17, minute: 30);
  String _returnTravelDays = 'Daily';
  String _returnDayMode = 'Daily';
  Set<String> _returnCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  bool _returnNotificationsEnabled = true;

  // Active Slot Getters & Setters
  String get _currentSource =>
      _selectedScheduleSlot == 0 ? _outboundSource : _returnSource;
  set _currentSource(String val) {
    if (_selectedScheduleSlot == 0) {
      _outboundSource = val;
    } else {
      _returnSource = val;
    }
  }

  String get _currentDestination =>
      _selectedScheduleSlot == 0 ? _outboundDestination : _returnDestination;
  set _currentDestination(String val) {
    if (_selectedScheduleSlot == 0) {
      _outboundDestination = val;
    } else {
      _returnDestination = val;
    }
  }

  TimeOfDay get _currentDepartureTime => _selectedScheduleSlot == 0
      ? _outboundDepartureTime
      : _returnDepartureTime;
  set _currentDepartureTime(TimeOfDay val) {
    if (_selectedScheduleSlot == 0) {
      _outboundDepartureTime = val;
    } else {
      _returnDepartureTime = val;
    }
  }

  TimeOfDay get _currentAlertTime =>
      _selectedScheduleSlot == 0 ? _outboundAlertTime : _returnAlertTime;
  set _currentAlertTime(TimeOfDay val) {
    if (_selectedScheduleSlot == 0) {
      _outboundAlertTime = val;
    } else {
      _returnAlertTime = val;
    }
  }

  String get _currentTravelDays =>
      _selectedScheduleSlot == 0 ? _outboundTravelDays : _returnTravelDays;
  set _currentTravelDays(String val) {
    if (_selectedScheduleSlot == 0) {
      _outboundTravelDays = val;
    } else {
      _returnTravelDays = val;
    }
  }

  String get _currentDayMode =>
      _selectedScheduleSlot == 0 ? _outboundDayMode : _returnDayMode;
  set _currentDayMode(String val) {
    if (_selectedScheduleSlot == 0) {
      _outboundDayMode = val;
    } else {
      _returnDayMode = val;
    }
  }

  Set<String> get _currentCustomDays =>
      _selectedScheduleSlot == 0 ? _outboundCustomDays : _returnCustomDays;

  bool get _currentNotificationsEnabled => _selectedScheduleSlot == 0
      ? _outboundNotificationsEnabled
      : _returnNotificationsEnabled;
  set _currentNotificationsEnabled(bool val) {
    if (_selectedScheduleSlot == 0) {
      _outboundNotificationsEnabled = val;
    } else {
      _returnNotificationsEnabled = val;
    }
  }

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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _swapRoutePoints() {
    setState(() {
      if (_selectedScheduleSlot == 0) {
        final tmp = _outboundSource;
        _outboundSource = _outboundDestination;
        _outboundDestination = tmp;
      } else {
        final tmp = _returnSource;
        _returnSource = _returnDestination;
        _returnDestination = tmp;
      }
    });
  }

  void _parseDaysForSlot(int slot, String rawDays) {
    final trimmed = rawDays.trim();
    if (trimmed == 'Daily') {
      if (slot == 0) {
        _outboundDayMode = 'Daily';
        _outboundCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
        _outboundTravelDays = 'Daily';
      } else {
        _returnDayMode = 'Daily';
        _returnCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
        _returnTravelDays = 'Daily';
      }
    } else if (trimmed == 'Sat-Sun' || trimmed == 'Weekends') {
      if (slot == 0) {
        _outboundDayMode = 'Weekends';
        _outboundCustomDays = {'Sat', 'Sun'};
        _outboundTravelDays = 'Sat-Sun';
      } else {
        _returnDayMode = 'Weekends';
        _returnCustomDays = {'Sat', 'Sun'};
        _returnTravelDays = 'Sat-Sun';
      }
    } else {
      final clean = trimmed.replaceFirst('Custom:', '');
      final parts = clean
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final set =
          parts.isEmpty ? {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'} : parts.toSet();
      const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sorted = dayOrder.where((d) => set.contains(d)).toList();
      if (slot == 0) {
        _outboundDayMode = 'Custom';
        _outboundCustomDays = set;
        _outboundTravelDays = sorted.join(',');
      } else {
        _returnDayMode = 'Custom';
        _returnCustomDays = set;
        _returnTravelDays = sorted.join(',');
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingReports = true);
    try {
      // 1. Load Outbound Commute Schedule
      final outbound = await _habitService.loadOutboundHabit();
      final outSrc = outbound['source']?.toString() ?? 'Panvel';
      final outDst = outbound['destination']?.toString() ?? 'Pune';
      if (_corridorPoints.contains(outSrc)) _outboundSource = outSrc;
      if (_corridorPoints.contains(outDst)) _outboundDestination = outDst;
      final outDepStr = outbound['departure_time']?.toString() ?? '08:00 AM';
      final outAlertStr = outbound['alert_time']?.toString() ?? '07:45 AM';
      _outboundDepartureTime = CommuteHabitService.parseTime(outDepStr);
      _outboundAlertTime = CommuteHabitService.parseTime(outAlertStr);
      _outboundNotificationsEnabled = outbound['is_enabled'] ?? true;
      _parseDaysForSlot(0, outbound['travel_days']?.toString() ?? 'Daily');

      // 2. Load Return Commute Schedule
      final returnHabit = await _habitService.loadReturnHabit();
      final retSrc = returnHabit['source']?.toString() ?? 'Pune';
      final retDst = returnHabit['destination']?.toString() ?? 'Panvel';
      if (_corridorPoints.contains(retSrc)) _returnSource = retSrc;
      if (_corridorPoints.contains(retDst)) _returnDestination = retDst;
      final retDepStr = returnHabit['departure_time']?.toString() ?? '06:00 PM';
      final retAlertStr = returnHabit['alert_time']?.toString() ?? '05:30 PM';
      _returnDepartureTime = CommuteHabitService.parseTime(retDepStr);
      _returnAlertTime = CommuteHabitService.parseTime(retAlertStr);
      _returnNotificationsEnabled = returnHabit['is_enabled'] ?? true;
      _parseDaysForSlot(1, returnHabit['travel_days']?.toString() ?? 'Daily');

      // 3. Load Community Radar Reports
      final res = await ApiService.getLiveCommunityReports(hours: 6);
      final list = (res['reports'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _liveReportsPreview = list.take(3).toList();
          _isLoadingReports = false;
        });
      }

      // 4. Load Dynamic Corridor Telemetry (OpenWeather + Google Maps Traffic)
      await _fetchLiveCorridorTelemetry();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _refreshLiveReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final res = await ApiService.getLiveCommunityReports(hours: 6);
      final list = (res['reports'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _liveReportsPreview = list.take(3).toList();
          _isLoadingReports = false;
        });
      }
      await _fetchLiveCorridorTelemetry();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _fetchLiveCorridorTelemetry() async {
    try {
      final telemetry = await ApiService.getCorridorTelemetry();
      if (telemetry != null && mounted) {
        setState(() {
          if (telemetry['corridor_safety_score'] is int) {
            _corridorSafetyScore = telemetry['corridor_safety_score'] as int;
          }
          if (telemetry['corridor_safety_badge'] != null) {
            _corridorSafetyBadge = telemetry['corridor_safety_badge'].toString();
          }
          if (telemetry['ghat_temperature'] != null) {
            _ghatTemperature = telemetry['ghat_temperature'].toString();
          }
          if (telemetry['ghat_condition'] != null) {
            _ghatCondition = telemetry['ghat_condition'].toString();
          }
          if (telemetry['corridor_traffic_summary'] != null) {
            _corridorTrafficSummary = telemetry['corridor_traffic_summary'].toString();
          }
          if (telemetry['corridor_traffic_badge'] != null) {
            _corridorTrafficBadge = telemetry['corridor_traffic_badge'].toString();
          }
          if (telemetry['corridor_traffic_color'] != null) {
            _corridorTrafficColor = _resolveStatusColor(telemetry['corridor_traffic_color']);
          }
          final rawNodes = telemetry['nodes'] as List?;
          if (rawNodes != null && rawNodes.isNotEmpty) {
            _expresswayNodes = rawNodes.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              m['statusColor'] = _resolveStatusColor(m['statusColor']);
              return m;
            }).toList();
          }
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // 12-HOUR AM/PM TIME PICKERS & SELECTORS
  // ============================================================

  Future<void> _pickTime({required bool isDeparture}) async {
    final initial = isDeparture ? _currentDepartureTime : _currentAlertTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      builder: (pickerContext, child) {
        return MediaQuery(
          data: MediaQuery.of(pickerContext).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDeparture) {
          _currentDepartureTime = picked;
          // Automatically set alert notice 15 minutes before departure
          int depMin = picked.hour * 60 + picked.minute;
          int alertMin = depMin - 15;
          if (alertMin < 0) alertMin += 1440;
          _currentAlertTime =
              TimeOfDay(hour: alertMin ~/ 60, minute: alertMin % 60);
        } else {
          _currentAlertTime = picked;
        }
      });
    }
  }

  void _setPeriod({required bool isDeparture, required bool isAm}) {
    setState(() {
      if (isDeparture) {
        int currentHour = _currentDepartureTime.hour;
        if (isAm && currentHour >= 12) currentHour -= 12;
        if (!isAm && currentHour < 12) currentHour += 12;
        _currentDepartureTime =
            TimeOfDay(hour: currentHour, minute: _currentDepartureTime.minute);
      } else {
        int currentHour = _currentAlertTime.hour;
        if (isAm && currentHour >= 12) currentHour -= 12;
        if (!isAm && currentHour < 12) currentHour += 12;
        _currentAlertTime =
            TimeOfDay(hour: currentHour, minute: _currentAlertTime.minute);
      }
    });
  }

  // ============================================================
  // COMMUTE SCHEDULE SAVE (DUAL SLOTS: OUTBOUND & RETURN)
  // ============================================================

  Future<void> _saveCommuteSchedule() async {
    final src = _currentSource;
    final dst = _currentDestination;
    if (src == dst) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting point and destination cannot be identical.'),
          backgroundColor: AppTheme.crimsonRed,
        ),
      );
      return;
    }

    setState(() => _isSavingSchedule = true);
    if (_currentNotificationsEnabled) {
      await NotificationService().requestPermission();
    }

    final formattedDep =
        CommuteHabitService.formatTime12h(_currentDepartureTime);
    final formattedAlert =
        CommuteHabitService.formatTime12h(_currentAlertTime);

    final bool success;
    final String slotName;
    if (_selectedScheduleSlot == 0) {
      slotName = 'Outbound Schedule';
      success = await _habitService.saveOutboundHabit(
        source: src,
        destination: dst,
        departureTime: formattedDep,
        alertTime: formattedAlert,
        travelDays: _currentTravelDays,
        isEnabled: _currentNotificationsEnabled,
      );
    } else {
      slotName = 'Return Schedule';
      success = await _habitService.saveReturnHabit(
        source: src,
        destination: dst,
        departureTime: formattedDep,
        alertTime: formattedAlert,
        travelDays: _currentTravelDays,
        isEnabled: _currentNotificationsEnabled,
      );
    }

    setState(() => _isSavingSchedule = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$slotName saved! ($formattedDep / Alert $formattedAlert)'
                : 'Failed to save $slotName.',
          ),
          backgroundColor:
              success ? const Color(0xFF1D4ED8) : AppTheme.crimsonRed,
        ),
      );
    }
  }

  // ============================================================
  // REAL DEVICE NOTIFICATION TEST
  // ============================================================

  Future<void> _triggerNotificationTest() async {
    final src = _currentSource;
    final dst = _currentDestination;
    if (src == dst) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting point and destination cannot be identical.'),
          backgroundColor: AppTheme.crimsonRed,
        ),
      );
      return;
    }

    setState(() => _isTestingAlert = true);
    await NotificationService().requestPermission();

    try {
      final alert = await _habitService.triggerTestAlert(
        source: src,
        destination: dst,
      );
      setState(() => _isTestingAlert = false);

      if (!mounted) return;

      if (alert != null) {
        final title = alert['title']?.toString() ??
            'Mumbai–Pune Commute Safety Alert';
        final body = alert['body']?.toString() ??
            'Corridor conditions evaluated.';
        final score = alert['safety_score'] is int
            ? alert['safety_score'] as int
            : int.tryParse(alert['safety_score']?.toString() ?? '70') ?? 70;
        final warnings = (alert['regional_warnings'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        await NotificationService().showCommuteNotification(
          title: title,
          body: body,
          score: score,
          warnings: warnings,
        );

        _showNotificationTestDialog(alert);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to evaluate commute notification alert. Please try again.'),
            backgroundColor: AppTheme.crimsonRed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isTestingAlert = false);
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) return;

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.darkNavy,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await ApiService.clearStoredSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to logout. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // APP OVERVIEW & GUIDE
  // ============================================================

  void _showAppOverviewGuide() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  decoration: const BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.forestGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Travel Advisor Guide',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkNavy,
                              ),
                            ),
                            Text(
                              'Overview of features & navigation',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildGuideFeatureItem(
                        icon: Icons.account_circle_rounded,
                        color: AppTheme.forestGreen,
                        title: '1. Profile Selection',
                        desc:
                            'Tap "Choose Profile" to select between Traveler (immediate journey monitoring) and Planner (future schedule forecasts).',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        customIcon: const LiveRadarIcon(
                          size: 20,
                          color: Color(0xFFEF4444),
                          showLivePulse: true,
                        ),
                        color: const Color(0xFFEF4444),
                        title: '2. Live Road Feeds',
                        desc:
                            'Real-time crowd reports covering visibility, rain, road surface, and traffic conditions across all expressway segments.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        customIcon: const CorridorHubIcon(
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        color: const Color(0xFF0284C7),
                        title: '3. Corridor Hub & Commute Alerts',
                        desc:
                            'Configure your regular commute route, departure time, and proactive notification alert. Test real notifications directly.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFF1E40AF),
                        title: '4. Dual Commute Schedules',
                        desc:
                            'Configure both Outbound (morning departure) and Return (evening heading back) commute alert schedules with independent times and custom active days.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.forestGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Got It',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideFeatureItem({
    IconData? icon,
    Widget? customIcon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: customIcon ?? Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCanvas,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x200F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        title: const Text(
          'Corridor Intelligence',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'App Overview & Guide',
            icon: const Icon(
              Icons.help_outline_rounded,
              color: AppTheme.darkNavy,
            ),
            onPressed: _showAppOverviewGuide,
          ),
          IconButton(
            tooltip: 'Saved Reports',
            icon: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppTheme.darkNavy,
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.savedReports);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoggingOut
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Logout',
                    onPressed: _showLogoutConfirmation,
                    icon: const Icon(Icons.logout_rounded),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshLiveReports,
          color: const Color(0xFF1D4ED8),
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // WELCOMING HERO HEADER
              _buildWelcomingHero(),

              const SizedBox(height: 14),

              // STREAMLINED PROFILE SELECTION ACTION BAR
              _buildCompactProfileBar(),

              const SizedBox(height: 18),

              // SEGMENTED TAB SELECTOR (Road Radar | Commute Setup | Saved Reports)
              _buildTabSelector(),

              const SizedBox(height: 16),

              // ACTIVE TAB CONTENT (Tab 0: Road Radar, Tab 1: Commute Setup, Tab 2: Saved Reports)
              if (_selectedTabIndex == 0)
                _buildLiveUpdatesSection()
              else if (_selectedTabIndex == 1)
                _buildCorridorHubSection()
              else
                _buildSavedReportsSection(),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WELCOMING HERO BANNER
  // ============================================================

  Widget _buildWelcomingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A1128), // Executive Midnight Obsidian
            Color(0xFF1E3A8A), // Royal Sapphire
            Color(0xFF1D4ED8), // Electric Cobalt
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A1128),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B), // Champagne Amber Accent
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'MUMBAI–PUNE EXPRESSWAY • NH48 / NE1',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFDE68A),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Corridor Intelligence\nCommand Center',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time expressway telemetry, multi-schedule commute alerts, and smart route risk intelligence.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Executive Live Telemetry Status Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_rounded, size: 12, color: Color(0xFF38BDF8)),
                    SizedBox(width: 5),
                    Text(
                      '94.5 KM MONITORED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFFA7F3D0)),
                    SizedBox(width: 5),
                    Text(
                      'ALL 8 SECTORS FLUID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFA7F3D0),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors_rounded, size: 12, color: Color(0xFFBAE6FD)),
                    SizedBox(width: 5),
                    Text(
                      'RADAR ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBAE6FD),
                        letterSpacing: 0.4,
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

  // ============================================================
  // STREAMLINED PROFILE SELECTION ACTION BAR
  // ============================================================

  Widget _buildCompactProfileBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141E3A8A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'PROFILE SELECTION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EXPRESSWAY SUITE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Title
          const Text(
            'Select Your Travel Persona',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkNavy,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Tailor expressway telemetry, hazard feeds, and predictive advice to your journey:',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          // Interactive Persona Cards (Traveler & Planner side-by-side)
          Row(
            children: [
              // Traveler Card
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.locationPermission,
                      arguments: {'role': 'traveler'},
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_car_rounded,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'EN ROUTE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Traveler',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Live Radar & Hazards',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Planner Card
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.locationPermission,
                      arguments: {'role': 'planner'},
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.event_note_rounded,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'PRE-TRIP',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Planner',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Forecasts & Advisories',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Full-Width Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1128), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x301D4ED8),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.roleSelection);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Configure Profile & Route Evaluation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEGMENTED TAB SELECTOR
  // ============================================================

  Widget _buildTabSelector() {
    final tabs = [
      {'title': 'Road Radar', 'icon': Icons.radar_rounded},
      {'title': 'Commute Setup', 'icon': Icons.schedule_rounded},
      {'title': 'Saved Reports', 'icon': Icons.bookmark_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedTabIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = idx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0A1128), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x302563EB),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[idx]['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tabs[idx]['title'] as String,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // 12-HOUR AM/PM TIME SELECTOR CARD
  // ============================================================

  Widget _buildTimeSelectorCard({
    required String label,
    required TimeOfDay time,
    required bool isDeparture,
  }) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final isAm = time.period == DayPeriod.am;

    final presets = isDeparture
        ? (_selectedScheduleSlot == 0
            ? const [
                TimeOfDay(hour: 7, minute: 30),
                TimeOfDay(hour: 8, minute: 0),
                TimeOfDay(hour: 8, minute: 30),
              ]
            : const [
                TimeOfDay(hour: 17, minute: 30),
                TimeOfDay(hour: 18, minute: 0),
                TimeOfDay(hour: 18, minute: 30),
              ])
        : (_selectedScheduleSlot == 0
            ? const [
                TimeOfDay(hour: 7, minute: 15),
                TimeOfDay(hour: 7, minute: 45),
                TimeOfDay(hour: 8, minute: 15),
              ]
            : const [
                TimeOfDay(hour: 17, minute: 15),
                TimeOfDay(hour: 17, minute: 45),
                TimeOfDay(hour: 18, minute: 15),
              ]);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isDeparture ? Icons.schedule_rounded : Icons.alarm_rounded,
                  size: 13,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickTime(isDeparture: isDeparture),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$hourStr:$minuteStr',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _setPeriod(isDeparture: isDeparture, isAm: true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: isAm
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isAm ? null : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isAm
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () =>
                            _setPeriod(isDeparture: isDeparture, isAm: false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: !isAm
                                ? const LinearGradient(
                                    colors: [Color(0xFF0A1128), Color(0xFF1E3A8A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: !isAm ? null : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: !isAm
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Quick presets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: presets.map((p) {
              final h = p.hourOfPeriod == 0 ? 12 : p.hourOfPeriod;
              final m = p.minute.toString().padLeft(2, '0');
              final isMatch = time.hour == p.hour && time.minute == p.minute;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isDeparture) {
                      _currentDepartureTime = p;
                      int depMin = p.hour * 60 + p.minute;
                      int alertMin = depMin - 15;
                      if (alertMin < 0) alertMin += 1440;
                      _currentAlertTime =
                          TimeOfDay(hour: alertMin ~/ 60, minute: alertMin % 60);
                    } else {
                      _currentAlertTime = p;
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isMatch
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isMatch
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '$h:$m',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isMatch ? FontWeight.w800 : FontWeight.w600,
                      color: isMatch
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: SAVED REPORTS ARCHIVE SECTION
  // ============================================================

  Widget _buildSavedReportsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Center(
                  child: SavedReportsBookmarkIcon(
                    size: 22,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAVED REPORTS ARCHIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'Bookmarked Travel Reports',
                      style: TextStyle(
                        fontSize: 16,
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
          const Text(
            'Access all your archived corridor trip risk assessments, weather observations, and departure recommendations saved during past planning sessions.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
              ),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.savedReports);
              },
              icon: const Icon(Icons.bookmark_added_rounded, size: 18),
              label: const Text(
                'Open Saved Reports Archive',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION 2: LIVE ROAD UPDATES & CORRIDOR HUB
  // ============================================================

  Widget _buildLiveUpdatesSection() {
    final selectedNode = _expresswayNodes[_selectedExpresswayNodeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. LIVE TELEMETRY STATS CARDS (Row of 3)
        Row(
          children: [
            Expanded(
              child: _buildTelemetryKpiCard(
                customIcon: const CorridorSafetyShieldIcon(size: 15, color: Color(0xFF10B981)),
                iconColor: const Color(0xFF10B981),
                value: '$_corridorSafetyScore/100',
                label: 'Corridor Safety',
                badgeText: _corridorSafetyBadge,
                badgeColor: _corridorSafetyScore >= 90 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTelemetryKpiCard(
                customIcon: const GhatMountainIcon(size: 15, color: Color(0xFF0284C7)),
                iconColor: const Color(0xFF0284C7),
                value: _ghatTemperature,
                label: 'Ghat Sector',
                badgeText: _ghatCondition,
                badgeColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTelemetryKpiCard(
                customIcon: CorridorTrafficLightIcon(
                  size: 15,
                  color: _corridorTrafficColor,
                ),
                iconColor: _corridorTrafficColor,
                value: _corridorTrafficSummary,
                label: 'Corridor Traffic',
                badgeText: _corridorTrafficBadge,
                badgeColor: _corridorTrafficColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. INTERACTIVE HIGHWAY CORRIDOR RIBBON (All 8 Nodes)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 6),
                      Text(
                        'EXPRESSWAY SECTOR TELEMETRY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '8 SECTORS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap any highway node to view real-time road conditions & advisory:',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Horizontal Scrollable Sector Ribbon
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _expresswayNodes.length,
                  separatorBuilder: (context, idx) => Center(
                    child: Container(
                      width: 14,
                      height: 2,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                  itemBuilder: (context, idx) {
                    final node = _expresswayNodes[idx];
                    final isSelected = _selectedExpresswayNodeIndex == idx;
                    final Color dotColor = _resolveStatusColor(node['statusColor']);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedExpresswayNodeIndex = idx;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Color(0xFF0A1128), Color(0xFF1D4ED8)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          color: isSelected ? null : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x301D4ED8),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  node['code'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? const Color(0xFFBAE6FD)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              node['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.darkNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (node['weather'] as String).split(' ').first,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // SELECTED SECTOR DEEP-DIVE CARD
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const SectorMapPinIcon(size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedNode['name']} Sector (${selectedNode['code']})',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Text(
                            selectedNode['status'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _resolveStatusColor(selectedNode['statusColor']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSectorMetricPill(
                          customIcon: const WeatherSunMetricIcon(size: 13, color: Color(0xFF1D4ED8)),
                          label: selectedNode['weather'] as String,
                        ),
                        const SizedBox(width: 6),
                        _buildSectorMetricPill(
                          customIcon: const SpeedometerMetricIcon(size: 13, color: Color(0xFF1D4ED8)),
                          label: 'Adv: ${selectedNode['speedAdvice']}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedNode['desc'] as String,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. COMMUNITY HAZARD RADAR CONTAINER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Center(
                          child: LiveRadarIcon(
                            size: 18,
                            color: Color(0xFFEF4444),
                            showLivePulse: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COMMUNITY HAZARD RADAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Live Motorist Feeds',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh Updates',
                        icon: _isLoadingReports
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: AppTheme.darkNavy,
                              ),
                        onPressed: _isLoadingReports ? null : _refreshLiveReports,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View All >',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Live hazard reports from drivers on the 8 expressway segments. Active for 6 hours.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingReports)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else if (_liveReportsPreview.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 20, color: Color(0xFF10B981)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All 8 Expressway Segments Clear. No active hazards or road obstructions reported in the past 6 hours.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._liveReportsPreview.map((rep) => _buildLiveReportItem(rep)),

              const SizedBox(height: 12),

              // Contribute Quick Action Banner
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign_rounded, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Text(
                            'Spotted an obstacle, fog, or rain?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '+ Report',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryKpiCard({
    IconData? icon,
    Widget? customIcon,
    required Color iconColor,
    required String value,
    required String label,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: customIcon ?? Icon(icon, size: 14, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectorMetricPill({
    IconData? icon,
    Widget? customIcon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          customIcon ?? Icon(icon, size: 12, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIVE REPORT CARD ITEM
  // ============================================================

  Widget _buildLiveReportItem(Map<String, dynamic> rep) {
    final regionName = rep['region_name']?.toString() ??
        _corridorSegmentMap[rep['route_region']] ??
        'Corridor Segment';
    final isRisky = rep['is_risky'] == true;
    final ageMinutes = rep['age_minutes'] ?? 0;

    String timeStr = '$ageMinutes min ago';
    final rawCreated = rep['created_at']?.toString() ?? '';
    if (rawCreated.contains('T')) {
      final timePart = rawCreated.split('T')[1].substring(0, 5);
      timeStr = '$timePart ($ageMinutes min ago)';
    }

    final hazards =
        (rep['hazards'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRisky ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRisky ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isRisky
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF0284C7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: HazardCategoryIcon(
                  category: isRisky ? 'hazard' : 'road',
                  size: 15,
                  color: isRisky
                      ? const Color(0xFFD97706)
                      : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  regionName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (hazards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hazards.take(4).map((h) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRisky
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRisky
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFF93C5FD),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HazardCategoryIcon(
                        category: h,
                        size: 13,
                        color: isRisky
                            ? const Color(0xFFB45309)
                            : const Color(0xFF1E40AF),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        h,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isRisky
                              ? const Color(0xFFB45309)
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // COMMUTE SETUP & DUAL NOTIFICATION SCHEDULER
  // ============================================================

  Widget _buildCorridorHubSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1E3A8A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECTION HEADER
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x252563EB),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: CommuteClockIcon(
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMUTE INTELLIGENCE SETUP',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Multi-Schedule Commute Alerts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Configure multiple notification schedules for your daily travels. Set independent alert times for your morning outbound trip and your evening return journey.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // DIRECTION SCHEDULE TOGGLE (Outbound vs Return)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedScheduleSlot = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _selectedScheduleSlot == 0
                            ? const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: _selectedScheduleSlot == 0
                            ? null
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _selectedScheduleSlot == 0
                            ? const [
                                BoxShadow(
                                  color: Color(0x281E3A8A),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            size: 15,
                            color: _selectedScheduleSlot == 0
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Outbound Commute',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedScheduleSlot == 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _selectedScheduleSlot == 0
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedScheduleSlot = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _selectedScheduleSlot == 1
                            ? const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: _selectedScheduleSlot == 1
                            ? null
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _selectedScheduleSlot == 1
                            ? const [
                                BoxShadow(
                                  color: Color(0x280F172A),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.nights_stay_rounded,
                            size: 15,
                            color: _selectedScheduleSlot == 1
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Return Commute',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedScheduleSlot == 1
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _selectedScheduleSlot == 1
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ROUTE CONTROLS WITH REVERSE ROUTE BUTTON
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('source_$_selectedScheduleSlot'),
                  initialValue: _corridorPoints.contains(_currentSource)
                      ? _currentSource
                      : _corridorPoints[1],
                  decoration: InputDecoration(
                    labelText: _selectedScheduleSlot == 0
                        ? 'Start Point (Morning)'
                        : 'Start Point (Return)',
                    labelStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    prefixIcon: const Icon(Icons.trip_origin,
                        size: 16, color: Color(0xFF1D4ED8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Color(0xFF1E3A8A)),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  items: _corridorPoints.map((point) {
                    return DropdownMenuItem<String>(
                      value: point,
                      child: Text(point, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _currentSource = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _swapRoutePoints,
                child: Tooltip(
                  message: 'Swap Start Point and Destination',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x301E3A8A),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: RouteSwapArrowIcon(
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dest_$_selectedScheduleSlot'),
                  initialValue: _corridorPoints.contains(_currentDestination)
                      ? _currentDestination
                      : _corridorPoints.last,
                  decoration: InputDecoration(
                    labelText: _selectedScheduleSlot == 0
                        ? 'Destination (Work)'
                        : 'Destination (Home)',
                    labelStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    prefixIcon: const Icon(Icons.location_on,
                        size: 16, color: Color(0xFFEF4444)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Color(0xFF1E3A8A)),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  items: _corridorPoints.map((point) {
                    return DropdownMenuItem<String>(
                      value: point,
                      child: Text(point, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _currentDestination = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // COMMUTE DAYS SELECTION
          Text(
            'Active Days for ${_selectedScheduleSlot == 0 ? "Outbound" : "Return"} Commute:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Daily', style: TextStyle(fontSize: 11.5)),
                selected: _currentDayMode == 'Daily',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _currentDayMode = 'Daily';
                      _currentCustomDays.clear();
                      _currentCustomDays.addAll(
                          {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'});
                      _currentTravelDays = 'Daily';
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Weekends', style: TextStyle(fontSize: 11.5)),
                selected: _currentDayMode == 'Weekends',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _currentDayMode = 'Weekends';
                      _currentCustomDays.clear();
                      _currentCustomDays.addAll({'Sat', 'Sun'});
                      _currentTravelDays = 'Sat-Sun';
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Custom Days', style: TextStyle(fontSize: 11.5)),
                selected: _currentDayMode == 'Custom',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _currentDayMode = 'Custom';
                      if (_currentCustomDays.isEmpty) {
                        _currentCustomDays
                            .addAll({'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
                      }
                      const dayOrder = [
                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                      ];
                      final sorted = dayOrder
                          .where((d) => _currentCustomDays.contains(d))
                          .toList();
                      _currentTravelDays = sorted.join(',');
                    });
                  }
                },
              ),
            ],
          ),
          if (_currentDayMode == 'Custom') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Days (Tap to toggle Monday to Sunday):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCorridorDayFilterChip('Mon', 'Monday'),
                      _buildCorridorDayFilterChip('Tue', 'Tuesday'),
                      _buildCorridorDayFilterChip('Wed', 'Wednesday'),
                      _buildCorridorDayFilterChip('Thu', 'Thursday'),
                      _buildCorridorDayFilterChip('Fri', 'Friday'),
                      _buildCorridorDayFilterChip('Sat', 'Saturday'),
                      _buildCorridorDayFilterChip('Sun', 'Sunday'),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // SCHEDULE TIMES (12-HOUR AM/PM SELECTION)
          Row(
            children: [
              Expanded(
                child: _buildTimeSelectorCard(
                  label: _selectedScheduleSlot == 0
                      ? 'Morning Departure'
                      : 'Evening Departure',
                  time: _currentDepartureTime,
                  isDeparture: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeSelectorCard(
                  label: 'Alert Notice Time',
                  time: _currentAlertTime,
                  isDeparture: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // NOTIFICATIONS SWITCH FOR CURRENT SLOT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedScheduleSlot == 0 ? "Outbound" : "Return"} Device Push Alerts',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      Text(
                        'AlarmManager ID: ${_selectedScheduleSlot == 0 ? "1001" : "1002"} • Local scheduled notice',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _currentNotificationsEnabled,
                  activeThumbColor: const Color(0xFF1D4ED8),
                  onChanged: (val) async {
                    setState(() => _currentNotificationsEnabled = val);
                    if (val) {
                      await NotificationService().requestPermission();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // SUMMARY CARD: BOTH COMMUTE SCHEDULES
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_customize_rounded,
                        size: 14, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 6),
                    Text(
                      'CONFIGURED COMMUTE SCHEDULES',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildScheduleSummaryRow(
                  slotTitle: '🌅 Outbound Commute',
                  route: '$_outboundSource → $_outboundDestination',
                  times:
                      '${CommuteHabitService.formatTime12h(_outboundDepartureTime)} (Alert: ${CommuteHabitService.formatTime12h(_outboundAlertTime)})',
                  isEnabled: _outboundNotificationsEnabled,
                  days: _outboundTravelDays,
                  isCurrent: _selectedScheduleSlot == 0,
                  onEdit: () => setState(() => _selectedScheduleSlot = 0),
                ),
                const SizedBox(height: 8),
                _buildScheduleSummaryRow(
                  slotTitle: '🌇 Return Commute',
                  route: '$_returnSource → $_returnDestination',
                  times:
                      '${CommuteHabitService.formatTime12h(_returnDepartureTime)} (Alert: ${CommuteHabitService.formatTime12h(_returnAlertTime)})',
                  isEnabled: _returnNotificationsEnabled,
                  days: _returnTravelDays,
                  isCurrent: _selectedScheduleSlot == 1,
                  onEdit: () => setState(() => _selectedScheduleSlot = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ACTIONS: SAVE CURRENT / SAVE BOTH / TEST ALERT
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x302563EB),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _isSavingSchedule ? null : _saveCommuteSchedule,
                    child: _isSavingSchedule
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Save ${_selectedScheduleSlot == 0 ? "Outbound" : "Return"}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF93C5FD), width: 1.5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _isTestingAlert ? null : _triggerNotificationTest,
                    child: _isTestingAlert
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_active_outlined,
                                  size: 16, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 6),
                              Text(
                                'Test Real Alert',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSavingSchedule ? null : _saveAllCommuteSchedules,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1D4ED8)),
              label: const Text(
                'Save Both Outbound & Return Schedules',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSummaryRow({
    required String slotTitle,
    required String route,
    required String times,
    required bool isEnabled,
    required String days,
    required bool isCurrent,
    required VoidCallback onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isCurrent ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF64748B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                slotTitle.contains('Outbound')
                    ? Icons.wb_sunny_rounded
                    : Icons.nights_stay_rounded,
                size: 14,
                color: isCurrent ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        slotTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCurrent
                              ? const Color(0xFF1E3A8A)
                              : AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isEnabled ? 'ACTIVE' : 'MUTED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isEnabled
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  Text(
                    '$times • $days',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isCurrent ? Icons.check_circle_rounded : Icons.edit_rounded,
              size: 16,
              color: isCurrent
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAllCommuteSchedules() async {
    setState(() => _isSavingSchedule = true);
    if (_outboundNotificationsEnabled || _returnNotificationsEnabled) {
      await NotificationService().requestPermission();
    }

    final outDep = CommuteHabitService.formatTime12h(_outboundDepartureTime);
    final outAlert = CommuteHabitService.formatTime12h(_outboundAlertTime);
    final retDep = CommuteHabitService.formatTime12h(_returnDepartureTime);
    final retAlert = CommuteHabitService.formatTime12h(_returnAlertTime);

    final outOk = await _habitService.saveOutboundHabit(
      source: _outboundSource,
      destination: _outboundDestination,
      departureTime: outDep,
      alertTime: outAlert,
      travelDays: _outboundTravelDays,
      isEnabled: _outboundNotificationsEnabled,
    );

    final retOk = await _habitService.saveReturnHabit(
      source: _returnSource,
      destination: _returnDestination,
      departureTime: retDep,
      alertTime: retAlert,
      travelDays: _returnTravelDays,
      isEnabled: _returnNotificationsEnabled,
    );

    setState(() => _isSavingSchedule = false);
    if (mounted) {
      final bothOk = outOk && retOk;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bothOk
                ? 'All commute schedules saved! (Outbound: $outDep / Return: $retDep)'
                : 'Failed to save all schedules.',
          ),
          backgroundColor:
              bothOk ? const Color(0xFF1D4ED8) : AppTheme.crimsonRed,
        ),
      );
    }
  }

  Widget _buildCorridorDayFilterChip(String code, String label) {
    final isSelected = _currentCustomDays.contains(code);
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentDayMode = 'Custom';
          if (!isSelected) {
            _currentCustomDays.add(code);
          } else {
            if (_currentCustomDays.length > 1) {
              _currentCustomDays.remove(code);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select at least one active day.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
          const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final sorted = dayOrder
              .where((d) => _currentCustomDays.contains(d))
              .toList();
          _currentTravelDays = sorted.join(',');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x252563EB),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            code.substring(0, 1),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION EVALUATION DIALOG
  // ============================================================

  Color _getScoreColor(int score) {
    if (score < 40) return AppTheme.crimsonRed;
    if (score < 60) return AppTheme.alertAmber;
    if (score < 75) return const Color(0xFFF59E0B);
    return AppTheme.forestGreen;
  }

  void _showNotificationTestDialog(Map<String, dynamic> alert) {
    final int score = alert['safety_score'] is int
        ? alert['safety_score'] as int
        : int.tryParse(alert['safety_score']?.toString() ?? '70') ?? 70;
    final Color scoreColor = _getScoreColor(score);
    final String title = alert['title']?.toString() ?? 'Commute Alert';
    final String body = alert['body']?.toString() ?? 'Corridor evaluated';
    final List warnings = (alert['regional_warnings'] as List?) ?? [];
    final String advice = alert['departure_advice']?.toString() ?? '';
    final String alertTime = alert['alert_time']?.toString() ?? '07:45';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      bottom:
                          BorderSide(color: scoreColor.withValues(alpha: 0.25)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REAL DEVICE NOTIFICATION SENT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppTheme.darkNavy,
                              ),
                            ),
                            Text(
                              'Evaluation Timestamp: $alertTime',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scoreColor.withValues(alpha: 0.14),
                              border: Border.all(color: scoreColor, width: 3),
                            ),
                            child: Center(
                              child: Text(
                                '$score',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: scoreColor,
                                ),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  alert['risk_level']?.toString() ??
                                      'Evaluated',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: scoreColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (warnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Route Hazards (Model + Community):',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...warnings.map((w) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: scoreColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.toString(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color: Color(0xFF0369A1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  advice,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0369A1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.forestGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
