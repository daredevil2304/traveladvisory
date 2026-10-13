import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState
    extends State<RoleSelectionScreen> {
  String? _selectedRole;

  bool _isLoggingOut = false;

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
      backgroundColor: AppTheme.lightMint,

      appBar: AppBar(
        backgroundColor: AppTheme.lightMint,
        elevation: 0,
        automaticallyImplyLeading: false,

        title: const Text(
          'Travel Advisor',
        ),

        actions: [
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
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 24,
          ),

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
                height: 32,
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
                    'I am travelling or about to travel.',
              ),

              const SizedBox(
                height: 16,
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

              const Spacer(),

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
}