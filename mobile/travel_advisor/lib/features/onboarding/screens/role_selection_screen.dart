import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/custom_corridor_icons.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final CommuteHabitService _habitService = CommuteHabitService();

  String? _selectedRole;
  bool _isLoggingOut = false;
  bool _isLoadingReports = false;
  bool _isTestingAlert = false;
  bool _isSavingSchedule = false;
  bool _isSliderExpanded = false;
  bool _showTutorialCoachmark = true;

  List<Map<String, dynamic>> _liveReportsPreview = [];

  // Controllers for direct schedule configuration inside the slider
  final TextEditingController _sourceCtrl =
      TextEditingController(text: 'Panvel');
  final TextEditingController _destCtrl = TextEditingController(text: 'Pune');
  final TextEditingController _depTimeCtrl =
      TextEditingController(text: '08:00');
  final TextEditingController _alertTimeCtrl =
      TextEditingController(text: '07:45');
  String _travelDays = 'Mon-Fri';
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
    _loadSliderData();
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _destCtrl.dispose();
    _depTimeCtrl.dispose();
    _alertTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSliderData() async {
    setState(() => _isLoadingReports = true);
    try {
      final seen = await const FlutterSecureStorage()
          .read(key: 'has_seen_slider_tutorial');
      if (seen == 'true' && mounted) {
        setState(() => _showTutorialCoachmark = false);
      }

      final habit = await _habitService.loadHabit();
      if (habit != null) {
        _sourceCtrl.text = habit['source'] ?? 'Panvel';
        _destCtrl.text = habit['destination'] ?? 'Pune';
        _depTimeCtrl.text = habit['departure_time'] ?? '08:00';
        _alertTimeCtrl.text = habit['alert_time'] ?? '07:45';
        _travelDays = habit['travel_days'] ?? 'Mon-Fri';
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

  Future<void> _dismissTutorialCoachmark() async {
    setState(() => _showTutorialCoachmark = false);
    try {
      await const FlutterSecureStorage().write(
        key: 'has_seen_slider_tutorial',
        value: 'true',
      );
    } catch (_) {}
  }

  // ============================================================
  // SCHEDULE SAVE
  // ============================================================

  Future<void> _saveCommuteSchedule() async {
    setState(() => _isSavingSchedule = true);
    if (_notificationsEnabled) {
      await NotificationService().requestPermission();
    }
    final success = await _habitService.saveHabit(
      source: _sourceCtrl.text.trim(),
      destination: _destCtrl.text.trim(),
      departureTime: _depTimeCtrl.text.trim(),
      alertTime: _alertTimeCtrl.text.trim(),
      travelDays: _travelDays,
      isEnabled: _notificationsEnabled,
    );
    setState(() => _isSavingSchedule = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Commute schedule saved successfully!'
                : 'Failed to save commute schedule.',
          ),
          backgroundColor:
              success ? AppTheme.forestGreen : AppTheme.crimsonRed,
        ),
      );
    }
  }

  // ============================================================
  // NOTIFICATION TEST TRIGGER
  // ============================================================

  Future<void> _triggerNotificationTest() async {
    setState(() => _isTestingAlert = true);
    await NotificationService().requestPermission();

    try {
      final dynamicSrc = _sourceCtrl.text.trim();
      final dynamicDst = _destCtrl.text.trim();
      final alert = await _habitService.triggerTestAlert(
        source: dynamicSrc.isNotEmpty ? dynamicSrc : 'Panvel',
        destination: dynamicDst.isNotEmpty ? dynamicDst : 'Pune',
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
  // CONTINUE
  // ============================================================

  void _continue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select how you are travelling.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.locationPermission,
      arguments: {
        'role': _selectedRole,
      },
    );
  }

  // ============================================================
  // LOGOUT CONFIRMATION
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
  // APP OVERVIEW & GUIDE DIALOG
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
                        icon: Icons.directions_car_rounded,
                        color: AppTheme.forestGreen,
                        title: '1. Traveler & Planner Profiles',
                        desc:
                            'Select Traveler for immediate route risk assessment with live radar, and Planner for scheduling future journey forecasts.',
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
                            'Community hazard updates on visibility, rain, road condition, and traffic along expressway segments in IST, active for 6 hours.',
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
                            'Set your recurring commute route, departure time, and alert notice in IST. Receive proactive notifications with safety scores before you depart.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.swipe_left_rounded,
                        color: const Color(0xFF0284C7),
                        title: '4. Expandable Side Drawer',
                        desc:
                            'Tap the docked capsule on the right screen edge and the in-page card anytime to quickly access Live Feeds and your Corridor Hub scheduler.',
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
      backgroundColor: AppTheme.lightMint,
      appBar: AppBar(
        backgroundColor: AppTheme.lightMint,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Toggle Corridor Hub Slider',
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
        title: const Text('Travel Advisor'),
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
            padding: const EdgeInsets.only(right: 12),
            child: _isLoggingOut
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
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
          // MAIN PROFILE SELECTION BODY
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Choose your profile.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose how you are travelling so we can personalize your journey experience.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),

                  // TRAVELER
                  _buildRoleCard(
                    role: 'traveler',
                    icon: Icons.directions_car_rounded,
                    title: 'Traveler',
                    description:
                        'Travelling immediately along the corridor.',
                  ),

                  const SizedBox(height: 16),

                  // PLANNER
                  _buildRoleCard(
                    role: 'planner',
                    icon: Icons.event_note_rounded,
                    title: 'Planner',
                    description:
                        'I am planning a journey for a future date.',
                  ),

                  const SizedBox(height: 18),

                  // IN-PAGE QUICK ACCESS TO CORRIDOR RADAR & COMMUTE HUB
                  GestureDetector(
                    onTap: () {
                      if (_showTutorialCoachmark) {
                        _dismissTutorialCoachmark();
                      }
                      setState(() => _isSliderExpanded = true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: const Center(
                              child: LiveRadarIcon(
                                size: 22,
                                color: Color(0xFFEF4444),
                                showLivePulse: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Live Feeds & Corridor Hub',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.darkNavy,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    CorridorHubIcon(
                                      size: 14,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Inspect real-time hazards & manage daily commute alerts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Color(0xFF1E40AF),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // CONTINUE
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoggingOut ? null : _continue,
                      child: const Text('CONTINUE'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // TRANSLUCENT BACKDROP WHEN SLIDER IS OPEN
          if (_isSliderExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isSliderExpanded = false);
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),

          // COLLAPSED EDGE ICON HANDLE WITH BOTH ICONS & TUTORIAL COACHMARK
          if (!_isSliderExpanded)
            Positioned(
              right: 0,
              top: MediaQuery.of(context).size.height * 0.36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // NEW USER TUTORIAL COACHMARK (Points to side slider)
                  if (_showTutorialCoachmark)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkNavy,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                color: Color(0xFF38BDF8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Corridor Quick Drawer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _dismissTutorialCoachmark,
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Tap to inspect live road updates and configure your daily commute schedule.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _dismissTutorialCoachmark,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.forestGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Got it',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // DOCKED DUAL-ICON SLIDER CAPSULE
                  GestureDetector(
                    onTap: () {
                      if (_showTutorialCoachmark) {
                        _dismissTutorialCoachmark();
                      }
                      setState(() => _isSliderExpanded = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        border: Border.all(
                            color: const Color(0xFF334155), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(-4, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. LIVE RADAR ICON
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: const LiveRadarIcon(
                              size: 19,
                              color: Color(0xFFEF4444),
                              showLivePulse: true,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // SEPARATOR
                          Container(
                            width: 20,
                            height: 1,
                            color: const Color(0xFF334155),
                          ),
                          const SizedBox(height: 6),

                          // 2. CORRIDOR HUB ICON
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: const CorridorHubIcon(
                              size: 19,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'HUB',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // CHEVRON EXPAND INDICATOR
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // EXPANDABLE SLIDER PANEL
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            right: _isSliderExpanded ? 0 : -sliderWidth,
            top: 0,
            bottom: 0,
            width: sliderWidth,
            child: _buildExpandableSliderPanel(context),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROLE CARD
  // ============================================================

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final bool selected = _selectedRole == role;

    return GestureDetector(
      onTap: _isLoggingOut
          ? null
          : () {
              setState(() {
                _selectedRole = role;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.forestGreen : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppTheme.forestGreen : AppTheme.mint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: selected ? AppTheme.white : AppTheme.forestGreen,
                size: 27,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.forestGreen,
                size: 26,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXPANDABLE SLIDER PANEL
  // ============================================================

  Widget _buildExpandableSliderPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // SLIDER HEADER WITH BOTH ICONS
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              decoration: const BoxDecoration(
                color: AppTheme.lightMint,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                ),
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
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
                        size: 20,
                        color: Color(0xFFEF4444),
                        showLivePulse: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7DD3FC)),
                    ),
                    child: const Center(
                      child: CorridorHubIcon(
                        size: 20,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Feeds & Corridor Hub',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Real-time hazards & commute alerts',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Collapse Slider',
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

            // SCROLLABLE SLIDER CONTENT
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // SECTION 1: LIVE ROAD UPDATES FEED
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const LiveRadarIcon(
                              size: 14,
                              color: Color(0xFFEF4444),
                              showLivePulse: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE ROAD UPDATES FEED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkNavy,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Refresh Feed',
                            icon: _isLoadingReports
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: AppTheme.darkNavy,
                                  ),
                            onPressed: _isLoadingReports
                                ? null
                                : _refreshLiveReports,
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _isSliderExpanded = false);
                              Navigator.pushNamed(
                                  context, AppRoutes.liveRoadUpdates);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'View All >',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.forestGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_isLoadingReports)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_liveReportsPreview.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No crowd reports in past 6 hours. Corridor clear.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._liveReportsPreview
                        .map((rep) => _buildLiveReportItem(rep)),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // SECTION 2: CORRIDOR HUB SCHEDULE SETTINGS
                  _buildScheduleEditor(),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // SECTION 3: SAVED REPORTS
                  _buildDrawerTile(
                    iconWidget: const SavedReportsBookmarkIcon(
                      size: 20,
                      color: Color(0xFF1E40AF),
                    ),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'Saved Reports',
                    subtitle: 'Inspect your saved journey assessments',
                    onTap: () {
                      setState(() => _isSliderExpanded = false);
                      Navigator.pushNamed(context, AppRoutes.savedReports);
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE REPORT ITEM IN SLIDER
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isRisky
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF0284C7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: HazardCategoryIcon(
                  category: isRisky ? 'hazard' : 'road',
                  size: 14,
                  color: isRisky
                      ? const Color(0xFFD97706)
                      : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  regionName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (hazards.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hazards.take(3).map((h) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        size: 12,
                        color: isRisky
                            ? const Color(0xFFB45309)
                            : const Color(0xFF1E40AF),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        h,
                        style: TextStyle(
                          fontSize: 11,
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
  // DIRECT COMMUTE SCHEDULE EDITOR INSIDE SLIDER
  // ============================================================

  Widget _buildScheduleEditor() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: const Center(
                  child: CommuteClockIcon(
                    size: 20,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CORRIDOR HUB: COMMUTE SCHEDULE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Proactive Route & Notification Setup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ROUTE INPUTS
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sourceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Starting Point',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.trip_origin,
                        size: 16, color: AppTheme.forestGreen),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _destCtrl,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.location_on,
                        size: 16, color: AppTheme.crimsonRed),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // COMMUTE DAYS CHIPS
          const Text(
            'Active Commute Days:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Monday to Friday',
                    style: TextStyle(fontSize: 11)),
                selected: _travelDays == 'Mon-Fri',
                selectedColor: AppTheme.mint,
                onSelected: (val) {
                  if (val) setState(() => _travelDays = 'Mon-Fri');
                },
              ),
              ChoiceChip(
                label: const Text('Daily', style: TextStyle(fontSize: 11)),
                selected: _travelDays == 'Daily',
                selectedColor: AppTheme.mint,
                onSelected: (val) {
                  if (val) setState(() => _travelDays = 'Daily');
                },
              ),
              ChoiceChip(
                label: const Text('Weekends', style: TextStyle(fontSize: 11)),
                selected: _travelDays == 'Sat-Sun',
                selectedColor: AppTheme.mint,
                onSelected: (val) {
                  if (val) setState(() => _travelDays = 'Sat-Sun');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SCHEDULE TIMES (IST)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _depTimeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Departure (IST)',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.schedule,
                        size: 16, color: Color(0xFF0284C7)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _alertTimeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Alert Notice (IST)',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.alarm,
                        size: 16, color: Color(0xFF0284C7)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // NOTIFICATIONS PERMISSION SWITCH
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
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
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Prompts system notification permission',
                        style: TextStyle(
                            fontSize: 10.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  activeThumbColor: AppTheme.forestGreen,
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
          const SizedBox(height: 12),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0369A1),
                    side: const BorderSide(color: Color(0xFF7DD3FC)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSavingSchedule ? null : _saveCommuteSchedule,
                  child: _isSavingSchedule
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Schedule',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isTestingAlert ? null : _triggerNotificationTest,
                  child: _isTestingAlert
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Test Real Notification',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
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
                // NOTIFICATION BANNER HEADER
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

                // BODY CONTENT
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

  // ============================================================
  // NAVIGATION TILE HELPER
  // ============================================================

  Widget _buildDrawerTile({
    required Widget iconWidget,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Center(child: iconWidget),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}