import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/custom_corridor_icons.dart';
import '../../../core/widgets/emergency_sos_sheet.dart';
import '../../location/services/location_service.dart';

class CorridorDashboardScreen extends StatefulWidget {
  const CorridorDashboardScreen({super.key});

  @override
  State<CorridorDashboardScreen> createState() =>
      _CorridorDashboardScreenState();
}

class _CorridorDashboardScreenState extends State<CorridorDashboardScreen>
    with WidgetsBindingObserver {
  final CommuteHabitService _habitService = CommuteHabitService();

  Timer? _telemetryTimer;

  bool _isLoggingOut = false;
  bool _isLoadingReports = false;
  bool _isTestingAlert = false;
  bool _isSavingSchedule = false;

  List<Map<String, dynamic>> _liveReportsPreview = [];
  List<Map<String, dynamic>> _savedReportsPreview = [];

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

  // Dynamic corridor telemetry KPI state variables
  int _corridorSafetyScore = 83;
  String _corridorSafetyBadge = 'Safe';
  String _ghatTemperature = '28°C';
  String _ghatCondition = 'Clear';
  String _corridorTrafficSummary = 'Free Flow';
  String _corridorTrafficBadge = 'Fluid';
  Color _corridorTrafficColor = const Color(0xFF10B981);

  static const List<Map<String, dynamic>> _defaultExpresswayNodes = [
    {
      'name': 'Mumbai',
      'code': 'BOM',
      'weather': '31°C Clear',
      'status': 'Normal Flow',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '60-80 km/h',
      'desc': 'Eastern Freeway & Mankhurd-Vashi flyover approaches. Normal metropolitan movement.',
    },
    {
      'name': 'Panvel',
      'code': 'PNV',
      'weather': '29°C Clear',
      'status': 'Expressway Entry',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '80-100 km/h',
      'desc': 'NE-1 Expressway entry & Kalamboli junction. 6 wide lanes open.',
    },
    {
      'name': 'Khalapur',
      'code': 'KHL',
      'weather': '28°C Clear',
      'status': 'Toll Plaza',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '100 km/h',
      'desc': 'Khalapur toll gates & food plaza area. High-visibility open corridor stretch.',
    },
    {
      'name': 'Khopoli',
      'code': 'KHP',
      'weather': '28°C Clear',
      'status': 'Ghat Approach',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '60-70 km/h',
      'desc': 'Base of the Sahyadri mountains. Heavy vehicle lane discipline strictly monitored.',
    },
    {
      'name': 'Bhor Ghat',
      'code': 'GHT',
      'weather': '28°C Clear',
      'status': 'Mountain Area',
      'statusColor': Color(0xFFF59E0B),
      'speedAdvice': '40-50 km/h',
      'desc': 'Steep gradient & hairpin curves. Maintain low gear and 50m braking distance.',
    },
    {
      'name': 'Lonavala',
      'code': 'LNV',
      'weather': '25°C Clear',
      'status': 'Plateau Section',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '70-80 km/h',
      'desc': 'Khandala viaduct & tunnel bypasses. Smooth road surface and clear conditions.',
    },
    {
      'name': 'Kamshet',
      'code': 'KMS',
      'weather': '25°C Clear',
      'status': 'Open Plains',
      'statusColor': Color(0xFF10B981),
      'speedAdvice': '90-100 km/h',
      'desc': 'Talegaon expressway run with twin tunnels. Free-flowing, unrestricted cruising.',
    },
    {
      'name': 'Pune',
      'code': 'PUN',
      'weather': '28°C Clear',
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
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _startPeriodicTelemetryTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whenever user opens or returns to the app, immediately fetch fresh traffic & telemetry
      _fetchLiveCorridorTelemetry(forceRefresh: true);
      _startPeriodicTelemetryTimer();
    } else if (state == AppLifecycleState.paused) {
      _telemetryTimer?.cancel();
    }
  }

  void _startPeriodicTelemetryTimer() {
    _telemetryTimer?.cancel();
    // Update live road traffic and expressway telemetry every 5 minutes while app is being used
    _telemetryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _fetchLiveCorridorTelemetry(forceRefresh: true);
      }
    });
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
      final res = await ApiService.getLiveCommunityReports(hours: 1);
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

      // 3b. Load Saved Reports Preview
      try {
        final userId = (await ApiService.getStoredUserId()) ?? 1;
        final saved = await ApiService.getSavedReports(userId: userId);
        if (mounted && saved.isNotEmpty) {
          final latest = saved.last;
          if (latest['overall_safety_score'] != null) {
            final s = latest['overall_safety_score'];
            if (s is num) {
              _corridorSafetyScore = s.toInt();
              _corridorSafetyBadge = _corridorSafetyScore >= 90
                  ? 'Optimal'
                  : (_corridorSafetyScore >= 80 ? 'Safe' : 'Caution');
            }
          }
          setState(() {
            _savedReportsPreview = saved.reversed.take(3).toList();
          });
        }
      } catch (_) {}

      // 4. Load Dynamic Corridor Telemetry (OpenWeather + Google Maps Traffic)
      await _fetchLiveCorridorTelemetry(forceRefresh: true);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _refreshLiveReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final res = await ApiService.getLiveCommunityReports(hours: 1);
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
      try {
        final userId = (await ApiService.getStoredUserId()) ?? 1;
        final saved = await ApiService.getSavedReports(userId: userId);
        if (mounted) {
          setState(() {
            _savedReportsPreview = saved.reversed.take(3).toList();
          });
        }
      } catch (_) {}
      await _fetchLiveCorridorTelemetry(forceRefresh: true);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  Future<void> _fetchLiveCorridorTelemetry({bool forceRefresh = false}) async {
    try {
      final telemetry = await ApiService.getCorridorTelemetry(forceRefresh: forceRefresh);
      if (telemetry != null && mounted) {
        setState(() {
          if (telemetry['corridor_safety_score'] != null) {
            final rawScore = telemetry['corridor_safety_score'];
            if (rawScore is num) {
              _corridorSafetyScore = rawScore.toInt();
            }
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

  void setPeriod({required bool isDeparture, required bool isAm}) {
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
      slotName = 'Morning Alert Settings';
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

    if (success) {
      await _habitService.fetchAlert(source: src, destination: dst);
    }

    setState(() => _isSavingSchedule = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Daily travel alerts saved! You will receive updates 15 mins before leaving.'
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
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFF0284C7),
                        title: '3. Daily Travel Alerts',
                        desc:
                            'Configure your daily travel route, departure time, and automatic road & weather alerts before you leave. Test alerts directly.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.sync_alt_rounded,
                        color: const Color(0xFF1E40AF),
                        title: '4. Morning & Return Alerts',
                        desc:
                            'Set independent departure alert times and travel days for your forward and return journeys.',
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
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
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
          'Weather Based Travel Advisory',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
          overflow: TextOverflow.ellipsis,
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
      floatingActionButton: const ExpresswaySosFloatingButton(
        heroTag: 'dashboard_welcome_sos_fab',
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
            Color(0xFF1E3A8A), // Royal Sapphire
            Color(0xFF1D4ED8), // Vivid Sapphire
            Color(0xFF2563EB), // Electric Cobalt
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x301E3A8A),
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
            'Weather Based Travel Advisory',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.4,
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
                      'ALL 8 AREAS SMOOTH',
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
            'Choose How You Travel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkNavy,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Are you driving right now or planning a future trip? Tap below to check road safety and traffic:',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          // Primary Full-Width Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
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
                    Icon(Icons.directions_car_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Check Route & Safety',
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
      {'title': 'Daily Alerts', 'icon': Icons.notifications_active_rounded},
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
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
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
  // TRAVEL TIMINGS CARD (CLEAN & SIMPLE 15-MIN PRIOR ALERT)
  // ============================================================

  Widget _buildHubTimingsCard() {
    return Row(
      children: [
        // Departure Time Card
        Expanded(
          child: InkWell(
            onTap: () => _pickTime(isDeparture: true),
            borderRadius: BorderRadius.circular(14),
            child: Container(
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
                    CommuteHabitService.formatTime12h(_currentDepartureTime),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to set departure',
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
            onTap: () => _pickTime(isDeparture: false),
            borderRadius: BorderRadius.circular(14),
            child: Container(
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
                    CommuteHabitService.formatTime12h(_currentAlertTime),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '15 min prior notice',
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

  // ============================================================
  // TAB 3: SAVED REPORTS ARCHIVE SECTION
  // ============================================================

  String _formatSavedReportDate(dynamic dateRaw) {
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

  Color _getSavedReportScoreColor(int score) {
    if (score < 45) return const Color(0xFFDC2626);
    if (score < 65) return const Color(0xFFF97316);
    if (score < 85) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _getSavedReportRiskLabel(int score) {
    if (score < 45) return 'High Risk';
    if (score < 65) return 'Caution';
    if (score < 85) return 'Moderate';
    return 'Safe';
  }

  Future<void> _openSavedReport(Map<String, dynamic> summary) async {
    final int reportId = summary['id'] is num ? (summary['id'] as num).toInt() : 0;
    if (reportId == 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the full report.')),
      );
    }
  }

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
                width: 42,
                height: 42,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAVED REPORTS ARCHIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Recent Trip Reports',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        if (_savedReportsPreview.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_savedReportsPreview.length} recent',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your saved trip reports. Tap any card to view your route safety score, weather, and driving tips.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_savedReportsPreview.isNotEmpty) ...[
            ..._savedReportsPreview.map((item) {
              final String title = item['title']?.toString() ?? 'Travel Report';
              final String dateStr = _formatSavedReportDate(item['created_at']);
              final dynamic scoreVal = item['safety_score'] ?? item['overall_safety_score'];
              final int score = scoreVal is num ? scoreVal.round() : 0;
              final Color scoreColor = _getSavedReportScoreColor(score);
              final String riskLabel = _getSavedReportRiskLabel(score);
              final String role = item['role']?.toString().toLowerCase() ?? 'traveler';
              final bool isPlanner = role == 'planner';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openSavedReport(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 38,
                            decoration: BoxDecoration(
                              color: scoreColor,
                              borderRadius: BorderRadius.circular(2),
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (dateStr.isNotEmpty) ...[
                                      const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isPlanner ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isPlanner ? 'PLANNER' : 'TRAVELER',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: isPlanner ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '$score • $riskLabel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
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
              label: Text(
                _savedReportsPreview.isNotEmpty
                    ? 'View All Saved Reports Archive'
                    : 'Open Saved Reports Archive',
                style: const TextStyle(
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

  Future<void> _navigateToChatbotOrPermission({required String role, String? sector}) async {
    try {
      final LocationService locationService = LocationService();
      final bool serviceEnabled = await locationService.isLocationServiceEnabled();
      if (serviceEnabled) {
        final LocationPermission permission = await locationService.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final Position position = await locationService.getCurrentLocation();
          if (!mounted) return;
          final Map<String, dynamic> chatArgs = {
            'role': role,
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
          if (sector != null) {
            chatArgs['sector'] = sector;
          }
          Navigator.pushNamed(
            context,
            AppRoutes.chatbot,
            arguments: chatArgs,
          );
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    final Map<String, dynamic> permArgs = {
      'role': role,
    };
    if (sector != null) {
      permArgs['sector'] = sector;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.locationPermission,
      arguments: permArgs,
    );
  }

  void _showSectorCopilotDialog(Map<String, dynamic> node) {
    final String sectorName = node['name'] as String? ?? 'Corridor';
    final String sectorCode = node['code'] as String? ?? 'NE-1';
    final String status = node['status'] as String? ?? 'Normal';
    final Color dotColor = _resolveStatusColor(node['statusColor']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.route_rounded,
                            size: 18, color: Color(0xFF1D4ED8)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$sectorName ($sectorCode)',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildSectorMetricPill(
                    customIcon: const WeatherSunMetricIcon(size: 13, color: Color(0xFF1D4ED8)),
                    label: node['weather'] as String? ?? 'Clear',
                  ),
                  const SizedBox(width: 8),
                  _buildSectorMetricPill(
                    customIcon: const SpeedometerMetricIcon(size: 13, color: Color(0xFF1D4ED8)),
                    label: 'Adv: ${node['speedAdvice'] ?? '80 km/h'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Option 1: Driving Now
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToChatbotOrPermission(role: 'traveler', sector: sectorName);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_car_rounded,
                          size: 20, color: Color(0xFF16A34A)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Driving Now (Live Updates)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Live GPS radar, real-time hazards & lane guidance',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: Color(0xFF16A34A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Planning Ahead
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToChatbotOrPermission(role: 'planner', sector: sectorName);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 20, color: Color(0xFF2563EB)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planning Ahead (Future Forecast)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Departure window forecast & route risk advice',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveUpdatesSection() {
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
                label: 'Highway Safety',
                badgeText: _corridorSafetyBadge,
                badgeColor: _corridorSafetyScore >= 85
                    ? const Color(0xFF10B981)
                    : (_corridorSafetyScore >= 65
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTelemetryKpiCard(
                customIcon: const GhatMountainIcon(size: 15, color: Color(0xFF0284C7)),
                iconColor: const Color(0xFF0284C7),
                value: _ghatTemperature,
                label: 'Ghat Weather',
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
                label: 'Highway Traffic',
                badgeText: _corridorTrafficBadge,
                badgeColor: _corridorTrafficColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. MINIMAL HIGHWAY ROUTE STRIP (All 8 Nodes - Clean Pulse)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
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
                  const Row(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 15, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 6),
                      Text(
                        'EXPRESSWAY ROUTE PULSE',
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
                      '8 ROAD REGIONS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                'Tap any area to check road risks with the assistant:',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Compact Horizontal Route Ribbon
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _expresswayNodes.length,
                  separatorBuilder: (context, idx) => Center(
                    child: Container(
                      width: 10,
                      height: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  itemBuilder: (context, idx) {
                    final node = _expresswayNodes[idx];
                    final Color dotColor = _resolveStatusColor(node['statusColor']);

                    return GestureDetector(
                      onTap: () => _showSectorCopilotDialog(node),
                      child: Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
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
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              node['name'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Direct AI Copilot Prompt Bar
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.roleSelection);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Have questions about your route? Ask the AI Travel Assistant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF1D4ED8)),
                    ],
                  ),
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
                            'COMMUNITY ROAD ALERTS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Live Driver Updates',
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
                'Live road updates reported by drivers on the expressway (valid for 1 hour).',
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
                          'All sections clear. No traffic jams, heavy rain, or road hazards reported in the past 1 hour.',
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
                            'Spotted rain, fog, or a traffic jam?',
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
                            '+ Share Update',
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
  // DAILY TRAVEL ALERTS (STREAMLINED 5-STEP SECTION)
  // ============================================================

  static const List<_HubDayItem> _hubDaysList = [
    _HubDayItem('Mon', 'M', 'Monday'),
    _HubDayItem('Tue', 'T', 'Tuesday'),
    _HubDayItem('Wed', 'W', 'Wednesday'),
    _HubDayItem('Thu', 'T', 'Thursday'),
    _HubDayItem('Fri', 'F', 'Friday'),
    _HubDayItem('Sat', 'S', 'Saturday'),
    _HubDayItem('Sun', 'S', 'Sunday'),
  ];

  void _setHubPresetDays(String preset) {
    setState(() {
      if (preset == 'weekdays') {
        _currentDayMode = 'Weekdays';
        _currentCustomDays.clear();
        _currentCustomDays.addAll({'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
        _currentTravelDays = 'Mon-Fri';
      } else if (preset == 'daily') {
        _currentDayMode = 'Daily';
        _currentCustomDays.clear();
        _currentCustomDays.addAll({'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'});
        _currentTravelDays = 'Daily';
      } else if (preset == 'weekends') {
        _currentDayMode = 'Weekends';
        _currentCustomDays.clear();
        _currentCustomDays.addAll({'Sat', 'Sun'});
        _currentTravelDays = 'Sat-Sun';
      }
    });
  }

  void _toggleHubDay(String code) {
    setState(() {
      if (_currentCustomDays.contains(code)) {
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
      } else {
        _currentCustomDays.add(code);
      }
      const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sorted = dayOrder.where((d) => _currentCustomDays.contains(d)).toList();
      if (sorted.length == 7) {
        _currentTravelDays = 'Daily';
        _currentDayMode = 'Daily';
      } else if (sorted.length == 2 && sorted.contains('Sat') && sorted.contains('Sun')) {
        _currentTravelDays = 'Sat-Sun';
        _currentDayMode = 'Weekends';
      } else if (sorted.length == 5 && !sorted.contains('Sat') && !sorted.contains('Sun')) {
        _currentTravelDays = 'Mon-Fri';
        _currentDayMode = 'Weekdays';
      } else {
        _currentTravelDays = sorted.join(',');
        _currentDayMode = 'Custom';
      }
    });
  }

  String _getHubDaysSummaryText() {
    if (_currentCustomDays.length == 7) return 'Alerts will arrive everyday before departure';
    if (_currentCustomDays.length == 5 &&
        !_currentCustomDays.contains('Sat') &&
        !_currentCustomDays.contains('Sun')) {
      return 'Alerts will arrive on weekdays (Monday to Friday)';
    }
    if (_currentCustomDays.length == 2 &&
        _currentCustomDays.contains('Sat') &&
        _currentCustomDays.contains('Sun')) {
      return 'Alerts will arrive on weekends (Saturday & Sunday)';
    }
    return 'Alerts active on ${_currentCustomDays.length} selected days';
  }

  Widget _buildCorridorHubSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.notifications_active_rounded,
                        size: 20,
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
                          'Daily Travel Alerts',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
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
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // CLEAN DIRECTION TOGGLE (Morning Trip vs Return Trip)
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedScheduleSlot = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _selectedScheduleSlot == 0
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                            color: _selectedScheduleSlot == 0 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedScheduleSlot == 0
                                ? const [
                                    BoxShadow(
                                      color: Color(0x281E3A8A),
                                      blurRadius: 4,
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
                                size: 14,
                                color: _selectedScheduleSlot == 0
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Morning Trip',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedScheduleSlot == 0
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: _selectedScheduleSlot == 0
                                      ? Colors.white
                                      : const Color(0xFF64748B),
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _selectedScheduleSlot == 1
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                            color: _selectedScheduleSlot == 1 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedScheduleSlot == 1
                                ? const [
                                    BoxShadow(
                                      color: Color(0x280F172A),
                                      blurRadius: 4,
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
                                size: 14,
                                color: _selectedScheduleSlot == 1
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Return Trip',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedScheduleSlot == 1
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: _selectedScheduleSlot == 1
                                      ? Colors.white
                                      : const Color(0xFF64748B),
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
            ],
          ),
        ),

        const SizedBox(height: 14),

        // STEP 1: TODAY'S ROAD STATUS (CLEAN REASSURING GREEN CARD)
        _buildHubRoadStatusCard(),

        const SizedBox(height: 14),

        // STEP 2: YOUR TRAVEL ROUTE (ORIGIN -> DESTINATION WITH SWAP)
        _buildHubRouteCard(),

        const SizedBox(height: 14),

        // STEP 3: TRAVEL TIMINGS (DEPARTURE & 15-MIN PRIOR ALERT)
        _buildHubTimingsCard(),

        const SizedBox(height: 14),

        // STEP 4: DAYS YOU TRAVEL (PRESETS + CIRCULAR DAY CHIPS)
        _buildHubDaysCard(),

        const SizedBox(height: 14),

        // STEP 5: AUTOMATIC NOTIFICATIONS TOGGLE
        _buildHubNotificationToggleCard(),

        const SizedBox(height: 20),

        // STEP 6: SAVE & TEST ACTIONS
        _buildHubActionButtons(),
      ],
    );
  }

  // ============================================================
  // STREAMLINED DAILY TRAVEL ALERTS WIDGETS
  // ============================================================

  Widget _buildHubRoadStatusCard() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _habitService.activeAlertNotifier,
      builder: (context, alert, child) {
        if (alert == null || (alert['warnings'] as List? ?? []).isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
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
                        'Expressway is Clear • $_currentSource ➔ $_currentDestination',
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

        final int score = (alert['safety_score'] as num?)?.toInt() ?? 80;
        final String risk = alert['risk_level'] ?? 'Normal';
        final List warnings = (alert['warnings'] as List?) ?? (alert['regional_warnings'] as List?) ?? [];
        final Color accentColor = score < 60
            ? const Color(0xFFDC2626)
            : (score < 80 ? const Color(0xFFD97706) : const Color(0xFF059669));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
                    '$_currentSource ➔ $_currentDestination',
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

  Widget _buildHubRouteCard() {
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
                      '$_currentSource ➔ $_currentDestination',
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
                          value: _corridorPoints.contains(_currentSource)
                              ? _currentSource
                              : _corridorPoints[1],
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
                            if (val != null) setState(() => _currentSource = val);
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
                        onTap: _swapRoutePoints,
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
                          value: _corridorPoints.contains(_currentDestination)
                              ? _currentDestination
                              : _corridorPoints.last,
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
                            if (val != null) setState(() => _currentDestination = val);
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

  Widget _buildHubDaysCard() {
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
                '${_currentCustomDays.length} days active',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Chips Row: Mon-Fri (Weekdays), Everyday, Weekends
          Row(
            children: [
              _buildHubPresetChip('Mon-Fri (Weekdays)', 'weekdays'),
              const SizedBox(width: 6),
              _buildHubPresetChip('Everyday', 'daily'),
              const SizedBox(width: 6),
              _buildHubPresetChip('Weekends', 'weekends'),
            ],
          ),

          const SizedBox(height: 12),

          // 7-Day Circular Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _hubDaysList.map((day) {
              final isSelected = _currentCustomDays.contains(day.code);
              return InkWell(
                onTap: () => _toggleHubDay(day.code),
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
            _getHubDaysSummaryText(),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHubPresetChip(String label, String presetKey) {
    bool isSelected = false;
    if (presetKey == 'weekdays') {
      isSelected = _currentDayMode == 'Weekdays' || (_currentCustomDays.length == 5 &&
          !_currentCustomDays.contains('Sat') &&
          !_currentCustomDays.contains('Sun'));
    } else if (presetKey == 'daily') {
      isSelected = _currentDayMode == 'Daily' || _currentCustomDays.length == 7;
    } else if (presetKey == 'weekends') {
      isSelected = _currentDayMode == 'Weekends' || (_currentCustomDays.length == 2 &&
          _currentCustomDays.contains('Sat') &&
          _currentCustomDays.contains('Sun'));
    }

    return InkWell(
      onTap: () => _setHubPresetDays(presetKey),
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

  Widget _buildHubNotificationToggleCard() {
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
                  'Checks rain, fog, and road conditions before you leave',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
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
    );
  }

  Widget _buildHubActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSavingSchedule ? null : _saveCommuteSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSavingSchedule
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
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isSavingSchedule ? null : _saveAllCommuteSchedules,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1D4ED8)),
            label: const Text(
              'Save Both Morning & Return Alerts',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isTestingAlert ? null : _triggerNotificationTest,
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
                ? 'Daily travel alerts saved! (Morning: $outDep / Return: $retDep)'
                : 'Failed to save all schedules.',
          ),
          backgroundColor:
              bothOk ? const Color(0xFF1D4ED8) : AppTheme.crimsonRed,
        ),
      );
    }
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
    final String title = alert['title']?.toString() ?? 'Travel Alert';
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

class _HubDayItem {
  final String code;
  final String initial;
  final String fullName;
  const _HubDayItem(this.code, this.initial, this.fullName);
}
