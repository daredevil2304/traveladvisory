import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends State<LocationPermissionScreen> {
  final LocationService _locationService = LocationService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExistingPermission());
  }

  Future<void> _checkExistingPermission() async {
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await _locationService.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _enableLocation();
      }
    } catch (_) {}
  }

  Future<void> _enableLocation() async {
    final routeArguments =
        ModalRoute.of(context)?.settings.arguments;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled =
          await _locationService.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await _locationService.openLocationSettings();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Please turn on Location Services and try again.';
        });

        return;
      }

      LocationPermission permission =
          await _locationService.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Location permission was denied. Please allow location access to continue.';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Location permission is permanently denied. Please enable it from App Settings.';
        });

        return;
      }

      final Position position =
          await _locationService.getCurrentLocation();

      String role = 'traveler';

      if (routeArguments is Map<String, dynamic>) {
        final passedRole = routeArguments['role'];
        if (passedRole is String && passedRole.isNotEmpty) {
          role = passedRole;
        }
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.chatbot,
        arguments: {
          'role': role,
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to get your location. Please try again.';
      });

      debugPrint('Location error: $e');
    }
  }

  Future<void> _openSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final bool permissionPermanentlyDenied =
        _errorMessage?.contains('permanently') == true;

    return Scaffold(
      backgroundColor: AppTheme.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.darkNavy,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Location Access',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // LOCATION ICON
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x101D4ED8),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 36,
                  color: Color(0xFF1D4ED8),
                ),
              ),

              const SizedBox(height: 24),

              // TITLE
              const Text(
                'Allow Location Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkNavy,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 8),

              // DESCRIPTION
              const Text(
                'We use your GPS to pinpoint your starting area and provide live highway weather and safety updates along your route.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              // INFO TILES
              _buildInfoTile(
                Icons.my_location_rounded,
                'Automatic Starting Point',
                'Your current road section is detected automatically.',
              ),

              const SizedBox(height: 12),

              _buildInfoTile(
                Icons.route_rounded,
                'Route Weather & Safety',
                'Get live warnings for heavy rain, fog, and traffic along your highway section.',
              ),

              const SizedBox(height: 12),

              _buildInfoTile(
                Icons.security_rounded,
                'Safe & Private',
                'Your location is used only while the app is active for your safety analysis.',
              ),

              const Spacer(),

              // ERROR MESSAGE
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        permissionPermanentlyDenied
                            ? Icons.settings_rounded
                            : Icons.info_outline_rounded,
                        color: const Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (permissionPermanentlyDenied)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1D4ED8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _openSettings,
                      child: const Text(
                        'OPEN APP SETTINGS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ),

                if (permissionPermanentlyDenied)
                  const SizedBox(height: 12),
              ],

              // ENABLE LOCATION BUTTON
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
                  onPressed: _isLoading ? null : _enableLocation,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 9),
                            Text(
                              'ALLOW LOCATION ACCESS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    final routeArguments =
                        ModalRoute.of(context)?.settings.arguments;
                    String role = 'traveler';
                    if (routeArguments is Map<String, dynamic>) {
                      final passedRole = routeArguments['role'];
                      if (passedRole is String && passedRole.isNotEmpty) {
                        role = passedRole;
                      }
                    }
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.chatbot,
                      arguments: {
                        'role': role,
                      },
                    );
                  },
                  child: const Text(
                    'SELECT LOCATION MANUALLY',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1D4ED8),
              size: 20,
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
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}