import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/custom_corridor_icons.dart';

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
                            'Community hazard updates on visibility, rain, road condition, and traffic along expressway segments, active for 6 hours.',
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
                            'Set your recurring commute route, departure time, and alert notice. Receive proactive notifications with safety scores before you depart.',
                      ),
                      const SizedBox(height: 14),
                      _buildGuideFeatureItem(
                        icon: Icons.bookmark_outline_rounded,
                        color: const Color(0xFF1E40AF),
                        title: '4. Saved Reports Archive',
                        desc:
                            'Quickly review past journey evaluations and AI corridor safety reports anytime.',
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
      backgroundColor: AppTheme.lightMint,
      appBar: AppBar(
        backgroundColor: AppTheme.lightMint,
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
        title: const Text('Select Profile'),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 6),
                    Text(
                      'AI JOURNEY CONFIGURATION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select Your Profile Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkNavy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Personalize corridor telemetry, live road radar feeds, and forecasting models to match your travel needs.',
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
                title: 'Immediate Traveler',
                description:
                    'Travelling right now along the corridor with live road sensor feeds & instant hazard alerts.',
                chips: const ['⚡ Live Radar', '🚨 Incident Alerts', '🌦️ Live Weather'],
              ),

              const SizedBox(height: 14),

              // PLANNER PERSONA
              _buildRoleCard(
                role: 'planner',
                icon: Icons.event_note_rounded,
                title: 'Future Journey Planner',
                description:
                    'Planning departure for a future date. Generates predictive risk forecasts and optimal departure timing.',
                chips: const ['📅 7-Day Forecast', '⏰ Departure Advisor', '📊 Safety Trends'],
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
                        'CONTINUE TO ROUTE SETUP',
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
    required String description,
    required List<String> chips,
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
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x202563EB)
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
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : const Color(0xFF475569),
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
                              ? const Color(0xFF1E3A8A)
                              : AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role == 'traveler' ? 'Active Real-Time Mode' : 'Predictive Forecast Mode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFF2563EB)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular Radio Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF64748B),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}