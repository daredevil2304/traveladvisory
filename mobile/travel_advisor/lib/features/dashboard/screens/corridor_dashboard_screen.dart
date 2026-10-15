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
  bool _isSliderExpanded = false;

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

  String _selectedSource = 'Panvel';
  String _selectedDestination = 'Pune';

  // Active segmented tab index (0: Commute Setup, 1: Live Road Radar, 2: Saved Reports)
  int _selectedTabIndex = 0;

  // 12-hour AM/PM Time representations (IST)
  TimeOfDay _selectedDepartureTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _selectedAlertTime = const TimeOfDay(hour: 7, minute: 45);

  // Controllers for schedule configuration
  final TextEditingController _depTimeCtrl =
      TextEditingController(text: '08:00 AM');
  final TextEditingController _alertTimeCtrl =
      TextEditingController(text: '07:45 AM');
  String _travelDays = 'Daily';
  String _commuteDayMode = 'Daily';
  Set<String> _selectedCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  bool _notificationsEnabled = true;

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

  @override
  void dispose() {
    _depTimeCtrl.dispose();
    _alertTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingReports = true);
    try {
      final habit = await _habitService.loadHabit();
      if (habit != null) {
        final src = habit['source']?.toString() ?? 'Panvel';
        final dst = habit['destination']?.toString() ?? 'Pune';
        if (_corridorPoints.contains(src)) {
          _selectedSource = src;
        }
        if (_corridorPoints.contains(dst)) {
          _selectedDestination = dst;
        }
        final depStr = habit['departure_time']?.toString() ?? '08:00 AM';
        final alertStr = habit['alert_time']?.toString() ?? '07:45 AM';
        _selectedDepartureTime = CommuteHabitService.parseTime(depStr);
        _selectedAlertTime = CommuteHabitService.parseTime(alertStr);
        _depTimeCtrl.text =
            CommuteHabitService.formatTime12h(_selectedDepartureTime);
        _alertTimeCtrl.text =
            CommuteHabitService.formatTime12h(_selectedAlertTime);
        final rawDays = (habit['travel_days']?.toString() ?? 'Daily').trim();
        if (rawDays == 'Daily') {
          _commuteDayMode = 'Daily';
          _selectedCustomDays = {
            'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
          };
          _travelDays = 'Daily';
        } else if (rawDays == 'Sat-Sun' || rawDays == 'Weekends') {
          _commuteDayMode = 'Weekends';
          _selectedCustomDays = {'Sat', 'Sun'};
          _travelDays = 'Sat-Sun';
        } else {
          _commuteDayMode = 'Custom';
          final clean = rawDays.replaceFirst('Custom:', '');
          final parts = clean
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (parts.isEmpty || rawDays == 'Mon-Fri') {
            _selectedCustomDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
          } else {
            _selectedCustomDays = parts.toSet();
          }
          const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final sorted =
              dayOrder.where((d) => _selectedCustomDays.contains(d)).toList();
          _travelDays = sorted.join(',');
        }
        _notificationsEnabled = habit['is_enabled'] ?? true;
      }

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
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  // ============================================================
  // 12-HOUR AM/PM TIME PICKERS & SELECTORS
  // ============================================================

  Future<void> _pickTime({required bool isDeparture}) async {
    final initial = isDeparture ? _selectedDepartureTime : _selectedAlertTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dial,
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
          _selectedDepartureTime = picked;
          _depTimeCtrl.text = CommuteHabitService.formatTime12h(picked);
          // Automatically set alert notice 15 minutes before departure
          int depMin = picked.hour * 60 + picked.minute;
          int alertMin = depMin - 15;
          if (alertMin < 0) alertMin += 1440;
          _selectedAlertTime =
              TimeOfDay(hour: alertMin ~/ 60, minute: alertMin % 60);
          _alertTimeCtrl.text =
              CommuteHabitService.formatTime12h(_selectedAlertTime);
        } else {
          _selectedAlertTime = picked;
          _alertTimeCtrl.text = CommuteHabitService.formatTime12h(picked);
        }
      });
    }
  }

  void _setPeriod({required bool isDeparture, required bool isAm}) {
    setState(() {
      if (isDeparture) {
        int currentHour = _selectedDepartureTime.hour;
        if (isAm && currentHour >= 12) currentHour -= 12;
        if (!isAm && currentHour < 12) currentHour += 12;
        _selectedDepartureTime =
            TimeOfDay(hour: currentHour, minute: _selectedDepartureTime.minute);
        _depTimeCtrl.text =
            CommuteHabitService.formatTime12h(_selectedDepartureTime);
      } else {
        int currentHour = _selectedAlertTime.hour;
        if (isAm && currentHour >= 12) currentHour -= 12;
        if (!isAm && currentHour < 12) currentHour += 12;
        _selectedAlertTime =
            TimeOfDay(hour: currentHour, minute: _selectedAlertTime.minute);
        _alertTimeCtrl.text =
            CommuteHabitService.formatTime12h(_selectedAlertTime);
      }
    });
  }

  // ============================================================
  // COMMUTE SCHEDULE SAVE
  // ============================================================

  Future<void> _saveCommuteSchedule() async {
    if (_selectedSource == _selectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting point and destination cannot be identical.'),
          backgroundColor: AppTheme.crimsonRed,
        ),
      );
      return;
    }

    setState(() => _isSavingSchedule = true);
    if (_notificationsEnabled) {
      await NotificationService().requestPermission();
    }

    final formattedDep =
        CommuteHabitService.formatTime12h(_selectedDepartureTime);
    final formattedAlert =
        CommuteHabitService.formatTime12h(_selectedAlertTime);

    final success = await _habitService.saveHabit(
      source: _selectedSource,
      destination: _selectedDestination,
      departureTime: formattedDep,
      alertTime: formattedAlert,
      travelDays: _travelDays,
      isEnabled: _notificationsEnabled,
    );
    setState(() => _isSavingSchedule = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Commute schedule saved! ($formattedDep / Alert $formattedAlert IST)'
                : 'Failed to save commute schedule.',
          ),
          backgroundColor:
              success ? AppTheme.forestGreen : AppTheme.crimsonRed,
        ),
      );
    }
  }

  // ============================================================
  // REAL DEVICE NOTIFICATION TEST
  // ============================================================

  Future<void> _triggerNotificationTest() async {
    if (_selectedSource == _selectedDestination) {
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
        source: _selectedSource,
        destination: _selectedDestination,
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
                            'Real-time crowd reports covering visibility, rain, road surface, and traffic conditions in IST across all expressway segments.',
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
                            'Configure your regular commute route, departure time, and proactive notification alert in IST. Test real notifications directly.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.menu_rounded,
                        color: const Color(0xFF1E40AF),
                        title: '4. Expandable Corridor Drawer',
                        desc:
                            'Tap the top menu button to open the sliding drawer anytime for fast access to live updates and commute management.',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final sliderWidth = screenWidth * 0.88;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Toggle Corridor Drawer',
          icon: Icon(
            _isSliderExpanded ? Icons.close_rounded : Icons.menu_rounded,
            color: AppTheme.darkNavy,
            size: 26,
          ),
          onPressed: () {
            setState(() {
              _isSliderExpanded = !_isSliderExpanded;
            });
          },
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
      body: Stack(
        children: [
          // MAIN SCROLLABLE CONTENT
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshLiveReports,
              color: const Color(0xFF1E40AF),
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

                  // SEGMENTED TAB SELECTOR (Commute Setup | Road Radar | Saved Reports)
                  _buildTabSelector(),

                  const SizedBox(height: 16),

                  // ACTIVE TAB CONTENT
                  if (_selectedTabIndex == 0)
                    _buildCorridorHubSection()
                  else if (_selectedTabIndex == 1)
                    _buildLiveUpdatesSection()
                  else
                    _buildSavedReportsSection(),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),

          // TRANSLUCENT BACKDROP WHEN SLIDER DRAWER IS EXPANDED
          if (_isSliderExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isSliderExpanded = false);
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),

          // EXPANDABLE SLIDER DRAWER PANEL
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            right: _isSliderExpanded ? 0 : -sliderWidth,
            top: 0,
            bottom: 0,
            width: sliderWidth,
            child: _buildDrawerPanel(context),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOMING HERO BANNER
  // ============================================================

  Widget _buildWelcomingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF1E40AF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241E40AF),
            blurRadius: 18,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiveRadarIcon(
                      size: 14,
                      color: Color(0xFF38BDF8),
                      showLivePulse: true,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'LIVE CORRIDOR TELEMETRY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'IST ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF86EFAC),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Welcome to Mumbai–Pune\nTravel Intelligence',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'High-precision expressway telemetry, crowd-sourced hazard feeds, and smart commute safety predictions.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(
              Icons.person_pin_circle_rounded,
              color: Color(0xFF1E40AF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Travel Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Traveler (immediate) • Planner (scheduled)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.roleSelection);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14),
              ],
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
      {'title': 'Commute Setup', 'icon': Icons.alarm_rounded},
      {'title': 'Road Radar', 'icon': Icons.radar_rounded},
      {'title': 'Saved Reports', 'icon': Icons.bookmark_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
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
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x140F172A),
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
                      tabs[idx]['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? const Color(0xFF1E40AF)
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
                            ? const Color(0xFF1E40AF)
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
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
              Icon(
                isDeparture ? Icons.schedule_rounded : Icons.alarm_rounded,
                size: 14,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickTime(isDeparture: isDeparture),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$hourStr:$minuteStr',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _setPeriod(isDeparture: isDeparture, isAm: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAm
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFFE2E8F0),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: !isAm
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFFE2E8F0),
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
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Tap to adjust • IST',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
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
                        'SECTION 2: COMMUNITY RADAR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Live Road Updates',
                        style: TextStyle(
                          fontSize: 16,
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
          const SizedBox(height: 10),
          const Text(
            'Verified hazard intelligence submitted by motorists along the 8 expressway segments. Active for 6 hours.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

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
                      'No hazards reported in the past 6 hours. Corridor conditions clear.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._liveReportsPreview.map((rep) => _buildLiveReportItem(rep)),
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
      timeStr = '$timePart IST ($ageMinutes min ago)';
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
  // SECTION 2B: CORRIDOR HUB COMMUTE SCHEDULER
  // ============================================================

  Widget _buildCorridorHubSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBAE6FD)),
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: const Center(
                  child: CommuteClockIcon(
                    size: 22,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CORRIDOR HUB: COMMUTE SETUP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'Automated Pre-Departure Alerts',
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
            'Configure your regular expressway commute route and preferred notice time in IST. Our system evaluates hazards before you start your drive.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // ROUTE DROPDOWNS
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _corridorPoints.contains(_selectedSource)
                      ? _selectedSource
                      : _corridorPoints[1],
                  decoration: InputDecoration(
                    labelText: 'Starting Point',
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    prefixIcon: const Icon(Icons.trip_origin,
                        size: 16, color: AppTheme.forestGreen),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Color(0xFF1E40AF)),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  items: _corridorPoints.map((point) {
                    return DropdownMenuItem<String>(
                      value: point,
                      child: Text(
                        point,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSource = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _corridorPoints.contains(_selectedDestination)
                      ? _selectedDestination
                      : _corridorPoints.last,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    prefixIcon: const Icon(Icons.location_on,
                        size: 16, color: AppTheme.crimsonRed),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Color(0xFF1E40AF)),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  items: _corridorPoints.map((point) {
                    return DropdownMenuItem<String>(
                      value: point,
                      child: Text(
                        point,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDestination = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // COMMUTE DAYS CHIPS
          const Text(
            'Active Commute Days:',
            style: TextStyle(
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
                selected: _commuteDayMode == 'Daily',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _commuteDayMode = 'Daily';
                      _selectedCustomDays = {
                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                      };
                      _travelDays = 'Daily';
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Weekends', style: TextStyle(fontSize: 11.5)),
                selected: _commuteDayMode == 'Weekends',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _commuteDayMode = 'Weekends';
                      _selectedCustomDays = {'Sat', 'Sun'};
                      _travelDays = 'Sat-Sun';
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Custom Days', style: TextStyle(fontSize: 11.5)),
                selected: _commuteDayMode == 'Custom',
                selectedColor: const Color(0xFFBFDBFE),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _commuteDayMode = 'Custom';
                      if (_selectedCustomDays.isEmpty) {
                        _selectedCustomDays = {
                          'Mon', 'Tue', 'Wed', 'Thu', 'Fri'
                        };
                      }
                      const dayOrder = [
                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                      ];
                      final sorted = dayOrder
                          .where((d) => _selectedCustomDays.contains(d))
                          .toList();
                      _travelDays = sorted.join(',');
                    });
                  }
                },
              ),
            ],
          ),
          if (_commuteDayMode == 'Custom') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Active Days (Monday to Sunday):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
          const SizedBox(height: 12),

          // SCHEDULE TIMES (12-HOUR AM/PM SELECTION IN IST)
          Row(
            children: [
              Expanded(
                child: _buildTimeSelectorCard(
                  label: 'Departure Time (IST)',
                  time: _selectedDepartureTime,
                  isDeparture: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeSelectorCard(
                  label: 'Alert Notice Time (IST)',
                  time: _selectedAlertTime,
                  isDeparture: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // NOTIFICATIONS PERMISSION SWITCH
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Push Notifications',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      Text(
                        'Triggers local notification before travel',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  activeThumbColor: const Color(0xFF1E40AF),
                  onChanged: (val) async {
                    setState(() => _notificationsEnabled = val);
                    if (val) {
                      await NotificationService().requestPermission();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ACTIONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0369A1),
                    side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSavingSchedule ? null : _saveCommuteSchedule,
                  child: _isSavingSchedule
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Schedule',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isTestingAlert ? null : _triggerNotificationTest,
                  child: _isTestingAlert
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Test Real Alert',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorridorDayFilterChip(String code, String label) {
    final isSelected = _selectedCustomDays.contains(code);
    return FilterChip(
      label: Text(
        code,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF1E3A8A) : AppTheme.darkNavy,
        ),
      ),
      tooltip: label,
      selected: isSelected,
      selectedColor: const Color(0xFFBFDBFE),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
        ),
      ),
      onSelected: (selected) {
        setState(() {
          _commuteDayMode = 'Custom';
          if (selected) {
            _selectedCustomDays.add(code);
          } else {
            if (_selectedCustomDays.length > 1) {
              _selectedCustomDays.remove(code);
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
              .where((d) => _selectedCustomDays.contains(d))
              .toList();
          _travelDays = sorted.join(',');
        });
      },
    );
  }



  // ============================================================
  // EXPANDABLE SLIDER DRAWER PANEL
  // ============================================================

  Widget _buildDrawerPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // DRAWER HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: const Center(
                      child: CorridorHubIcon(
                        size: 20,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Corridor Hub Drawer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Quick access navigation',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Drawer',
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.darkNavy,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() => _isSliderExpanded = false);
                    },
                  ),
                ],
              ),
            ),

            // DRAWER CONTENT ITEMS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildDrawerItem(
                    iconWidget: const Icon(Icons.person_pin_circle_rounded,
                        color: Color(0xFF1E40AF), size: 22),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'Profile Selection',
                    subtitle: 'Choose Traveler and Planner personas',
                    onTap: () {
                      setState(() => _isSliderExpanded = false);
                      Navigator.pushNamed(context, AppRoutes.roleSelection);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    iconWidget: const LiveRadarIcon(
                      size: 20,
                      color: Color(0xFFEF4444),
                      showLivePulse: true,
                    ),
                    iconBg: const Color(0xFFFEF2F2),
                    title: 'Live Road Feeds',
                    subtitle: 'Full community reports across segments',
                    onTap: () {
                      setState(() => _isSliderExpanded = false);
                      Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    iconWidget: const SavedReportsBookmarkIcon(
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                    iconBg: const Color(0xFFF1F5F9),
                    title: 'Saved Reports',
                    subtitle: 'View historical journey risk predictions',
                    onTap: () {
                      setState(() => _isSliderExpanded = false);
                      Navigator.pushNamed(context, AppRoutes.savedReports);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // IN-DRAWER COMMUTE CONTROLS
                  const Text(
                    'QUICK COMMUTE ACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isTestingAlert ? null : _triggerNotificationTest,
                    child: _isTestingAlert
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Trigger Test Notification',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
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
  }

  Widget _buildDrawerItem({
    required Widget iconWidget,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(child: iconWidget),
              ),
              const SizedBox(width: 12),
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
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppTheme.textSecondary,
              ),
            ],
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
                              'Evaluation Timestamp: $alertTime IST',
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
