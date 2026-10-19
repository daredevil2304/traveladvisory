import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/custom_corridor_icons.dart';
import '../../location/services/location_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoggingOut = false;

  // ============================================================
  // CONTINUE ACTION
  // ============================================================

  Future<void> _continue() async {
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

    try {
      final LocationService locationService = LocationService();
      final bool serviceEnabled = await locationService.isLocationServiceEnabled();
      if (serviceEnabled) {
        final LocationPermission permission = await locationService.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final Position position = await locationService.getCurrentLocation();
          if (!mounted) return;
          Navigator.pushNamed(
            context,
            AppRoutes.chatbot,
            arguments: {
              'role': _selectedRole,
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
          );
          return;
        }
      }
    } catch (_) {
      // Fall through to location permission screen if not granted
    }

    if (!mounted) return;
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
                              'How This App Works',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkNavy,
                              ),
                            ),
                            Text(
                              'Quick guide for drivers',
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
                        title: '1. Driving Now vs. Planning Later',
                        desc:
                            'Select "Driving Now" for live traffic and weather while on the road. Select "Planning Later" to check safety for a future trip.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        customIcon: const LiveRadarIcon(
                          size: 20,
                          color: Color(0xFFEF4444),
                          showLivePulse: true,
                        ),
                        color: const Color(0xFFEF4444),
                        title: '2. Live Road Updates',
                        desc:
                            'See and share live reports about rain, fog, traffic, and road conditions along the expressway.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        customIcon: const CorridorHubIcon(
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        color: const Color(0xFF0284C7),
                        title: '3. Daily Commute Alerts',
                        desc:
                            'Save your regular travel times to get automatic safety alerts before you leave.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.bookmark_outline_rounded,
                        color: const Color(0xFF1E40AF),
                        title: '4. Saved Trip Reports',
                        desc:
                            'Review your past trip safety scores and driving advice anytime.',
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
        leading: IconButton(
          tooltip: 'Back to Dashboard',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkNavy,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Choose Travel Type'),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              const Text(
                'How are you travelling?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkNavy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose whether you are driving right now or planning a trip for a future date.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // TRAVELER PERSONA
              _buildRoleCard(
                role: 'traveler',
                icon: Icons.directions_car_rounded,
                title: 'Driving Now',
                subtitle: 'On the road today',
                badgeText: 'LIVE TRIP',
                description:
                    'I am travelling right now. Show me live traffic, rain, fog, and road safety alerts along the highway in real time.',
              ),

              const SizedBox(height: 14),

              // PLANNER PERSONA
              _buildRoleCard(
                role: 'planner',
                icon: Icons.event_note_rounded,
                title: 'Planning for Later',
                subtitle: 'Trip on a future date',
                badgeText: 'FUTURE TRIP',
                description:
                    'I want to plan a future trip. Check the weather forecast, Ghat road conditions, and the best time to leave.',
              ),

              const Spacer(),

              // CONTINUE BUTTON
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x302563EB),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoggingOut ? null : _continue,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROLE CARD (PERSONA SELECTION)
  // ============================================================

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required String description,
  }) {
    final bool selected = _selectedRole == role;
    final bool isTraveler = role == 'traveler';

    // Distinctive color palettes matching the flagship dashboard cards
    final Color accentColor = isTraveler ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final Color selectedBg = isTraveler ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF);
    final Color selectedBorder = isTraveler ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final Color badgeBg = isTraveler ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE);
    final Color badgeTextColor = isTraveler ? const Color(0xFF15803D) : const Color(0xFF1D4ED8);

    return GestureDetector(
      onTap: _isLoggingOut
          ? null
          : () {
              setState(() {
                _selectedRole = role;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedBorder : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accentColor.withValues(alpha: 0.18)
                  : const Color(0x060F172A),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor.withValues(alpha: 0.15)
                        : (isTraveler ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? accentColor.withValues(alpha: 0.4)
                          : (isTraveler ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? (isTraveler ? const Color(0xFF065F46) : const Color(0xFF1E3A8A))
                              : AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? accentColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flagship Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? accentColor.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Circular Radio Indicator
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? accentColor
                          : const Color(0xFFCBD5E1),
                      width: selected ? 6 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}