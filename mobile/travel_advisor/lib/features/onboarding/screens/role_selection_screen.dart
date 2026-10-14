import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState
    extends State<RoleSelectionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CommuteHabitService _habitService = CommuteHabitService();

  String? _selectedRole;
  bool _isLoggingOut = false;
  bool _isLoadingReports = false;
  bool _isTestingAlert = false;
  List<Map<String, dynamic>> _liveReportsPreview = [];

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
    _loadDrawerData();
  }

  Future<void> _loadDrawerData() async {
    setState(() => _isLoadingReports = true);
    try {
      await _habitService.loadHabit();
      final res = await ApiService.getLiveCommunityReports(hours: 6);
      final list = (res['reports'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];
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
    if (_isLoggingOut) {
      return;
    }

    final bool? shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'CANCEL',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'LOGOUT',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Clear the locally stored login session.
      await ApiService.clearStoredSession();

      if (!mounted) {
        return;
      }

      /*
       * Remove every previous route from the navigation stack.
       *
       * This is important because after logout the user
       * must not be able to press Back and return to the
       * authenticated part of the application.
       */
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to logout. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.lightMint,

      drawer: _buildDrawer(context),

      appBar: AppBar(
        backgroundColor: AppTheme.lightMint,
        elevation: 0,
        automaticallyImplyLeading: false,

        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(
              Icons.menu_rounded,
              color: AppTheme.darkNavy,
              size: 26,
            ),
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),

        title: const Text(
          'Travel Advisor',
        ),

        actions: [
          IconButton(
            tooltip: 'Live Road Updates',
            icon: const Icon(
              Icons.campaign_outlined,
              color: AppTheme.darkNavy,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.liveRoadUpdates,
              );
            },
          ),
          IconButton(
            tooltip: 'Saved Reports',
            icon: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppTheme.darkNavy,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.savedReports,
              );
            },
          ),
          Padding(
            padding:
                const EdgeInsets.only(right: 12),

            child: _isLoggingOut
                ? const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child:
                          SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Logout',
                    onPressed:
                        _showLogoutConfirmation,
                    icon: const Icon(
                      Icons.logout_rounded,
                    ),
                  ),
          ),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 20,
                      ),

                      Text(
                        'Choose your profile.',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium,
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        'Choose how you are travelling so we can personalize your journey experience.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge,
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      // ==================================================
                      // TRAVELER
                      // ==================================================

                      _buildRoleCard(
                        role: 'traveler',
                        icon:
                            Icons.directions_car_rounded,
                        title: 'Traveler',
                        description:
                            'Travelling immediately along the corridor.',
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ==================================================
                      // PLANNER
                      // ==================================================

                      _buildRoleCard(
                        role: 'planner',
                        icon:
                            Icons.event_note_rounded,
                        title: 'Planner',
                        description:
                            'I am planning a journey for a future date.',
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ==================================================
                      // SIDEBAR DRAWER TRIGGER
                      // ==================================================

                      _buildSidebarTriggerCard(),

                      const Spacer(),

                      const SizedBox(
                        height: 16,
                      ),

                      // ==================================================
                      // CONTINUE
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,

                        child: ElevatedButton(
                          onPressed: _isLoggingOut
                              ? null
                              : _continue,

                          child: const Text(
                            'CONTINUE',
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
    final bool selected =
        _selectedRole == role;

    return GestureDetector(
      onTap: _isLoggingOut
          ? null
          : () {
              setState(() {
                _selectedRole = role;
              });
            },

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),

        width: double.infinity,

        padding:
            const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: AppTheme.white,

          borderRadius:
              BorderRadius.circular(18),

          border: Border.all(
            color: selected
                ? AppTheme.forestGreen
                : AppTheme.border,

            width: selected ? 2 : 1,
          ),
        ),

        child: Row(
          children: [
            // ==================================================
            // ICON
            // ==================================================

            Container(
              width: 52,
              height: 52,

              decoration:
                  BoxDecoration(
                color: selected
                    ? AppTheme.forestGreen
                    : AppTheme.mint,

                borderRadius:
                    BorderRadius.circular(15),
              ),

              child: Icon(
                icon,

                color: selected
                    ? AppTheme.white
                    : AppTheme.forestGreen,

                size: 27,
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            // ==================================================
            // TEXT
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          AppTheme.darkNavy,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    description,

                    style:
                        const TextStyle(
                      fontSize: 13,
                      color:
                          AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SELECTED CHECK
            // ==================================================

            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color:
                    AppTheme.forestGreen,
                size: 26,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIDEBAR DRAWER TRIGGER CARD
  // ============================================================

  Widget _buildSidebarTriggerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.forestGreen.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forestGreen.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.menu_open_rounded,
                    color: AppTheme.forestGreen,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Corridor Hub & Live Feeds',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE65100),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FEED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Slide open sidebar for live crowd updates, saved reports & commute alerts',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.forestGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Slide',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SIDEBAR DRAWER
  // ============================================================

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // TOP HEADER with close button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: AppTheme.lightMint,
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.forestGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Sidebar',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.darkNavy,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Corridor Intelligence Hub',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Live crowd reports, saved records & alerts',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // SCROLLABLE DRAWER BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // ==========================================
                  // SECTION 1: LIVE ROAD UPDATES FEED
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            size: 18,
                            color: Color(0xFFE65100),
                          ),
                          SizedBox(width: 6),
                          Text(
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
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.liveRoadUpdates);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No crowd reports in past 6 hours. Corridor clear.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._liveReportsPreview.map((rep) => _buildLiveReportItem(rep)),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // ==========================================
                  // SECTION 2: SAVED REPORTS TILE
                  // ==========================================
                  _buildDrawerTile(
                    icon: Icons.bookmark_rounded,
                    iconColor: AppTheme.forestGreen,
                    iconBg: AppTheme.mint,
                    title: 'Saved Reports',
                    subtitle: 'Inspect your saved journey assessments',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.savedReports);
                    },
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // ==========================================
                  // SECTION 3: DAILY COMMUTE ROUTE & ALERTS
                  // ==========================================
                  _buildCommuteScheduleSection(context),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // LOGOUT AT BOTTOM
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.logout_rounded,
                color: AppTheme.crimsonRed,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.crimsonRed,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE REPORT ITEM IN DRAWER
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRisky ? const Color(0xFFFFF8F1) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRisky ? const Color(0xFFFFD8A8) : const Color(0xFFBBF7D0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRisky
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 16,
                color: isRisky ? const Color(0xFFE65100) : AppTheme.forestGreen,
              ),
              const SizedBox(width: 6),
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: hazards.take(3).map((h) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRisky ? const Color(0xFFFFE8D6) : AppTheme.mint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isRisky
                          ? const Color(0xFFC05621)
                          : AppTheme.forestGreen,
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

  // ============================================================
  // COMMUTE SCHEDULE SECTION IN DRAWER
  // ============================================================

  Widget _buildCommuteScheduleSection(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _habitService.commuteHabitNotifier,
      builder: (context, habit, child) {
        final src = habit?['source'] ?? 'Panvel';
        final dst = habit?['destination'] ?? 'Pune';
        final depTime = habit?['departure_time'] ?? '08:00';
        final alertTime = habit?['alert_time'] ?? '07:45';
        final travelDays = habit?['travel_days'] ?? 'Mon-Fri';

        String daysText = 'Monday to Friday';
        if (travelDays == 'Daily') daysText = 'Daily (All Days)';
        if (travelDays == 'Sat-Sun') daysText = 'Weekends';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.alarm_on_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY COMMUTE ROUTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Proactive Safety Alerts',
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Route & Days:',
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                        Text(
                          '$src → $dst • $daysText',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Schedule (IST):',
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Leaves $depTime IST • Alert $alertTime IST',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0369A1),
                        side: const BorderSide(color: Color(0xFF7DD3FC)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.commuteAlerts);
                      },
                      child: const Text(
                        'Edit Schedule',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isTestingAlert
                          ? null
                          : () => _triggerNotificationTest(context),
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
                              'Test Alert Now',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // NOTIFICATION TEST TRIGGER & MODAL
  // ============================================================

  Future<void> _triggerNotificationTest(BuildContext drawerContext) async {
    setState(() => _isTestingAlert = true);
    try {
      final alert = await _habitService.triggerTestAlert();
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
                  color: Colors.black.withOpacity(0.18),
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
                    color: scoreColor.withOpacity(0.12),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      bottom: BorderSide(color: scoreColor.withOpacity(0.25)),
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
                              'PROACTIVE COMMUTE ALERT',
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
                      // SCORE ROW
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scoreColor.withOpacity(0.14),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.darkNavy,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.forestGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.pushNamed(
                                    context, AppRoutes.commuteAlerts);
                              },
                              child: const Text(
                                'Manage Schedule',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
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
  // DRAWER NAVIGATION TILE HELPER
  // ============================================================

  Widget _buildDrawerTile({
    required IconData icon,
    required Color iconColor,
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
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
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