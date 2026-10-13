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
  final LocationService _locationService =
      LocationService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _enableLocation() async {
    // Capture route arguments before any async gap.
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
        permission =
            await _locationService.requestPermission();
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

      if (permission ==
          LocationPermission.deniedForever) {
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

      debugPrint(
        'GPS location detected successfully.',
      );
      debugPrint(
        'Latitude: ${position.latitude}',
      );
      debugPrint(
        'Longitude: ${position.longitude}',
      );

      String role = 'traveler';

      if (routeArguments is Map<String, dynamic>) {
        final passedRole =
            routeArguments['role'];

        if (passedRole is String &&
            passedRole.isNotEmpty) {
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
      backgroundColor: AppTheme.lightMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              // ------------------------------------------------------
              // LOCATION ICON
              // ------------------------------------------------------
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.mint,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 34,
                  color: AppTheme.forestGreen,
                ),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------------
              // TITLE
              // ------------------------------------------------------
              Text(
                'Allow Location Access',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------------
              // DESCRIPTION
              // ------------------------------------------------------
              Text(
                'We use your location to identify your starting point and provide travel safety information for your journey.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),

              const SizedBox(height: 28),

              // ------------------------------------------------------
              // INFO TILE 1
              // ------------------------------------------------------
              _buildInfoTile(
                Icons.my_location_rounded,
                'Auto-detect starting point',
                'Your current location will be detected automatically.',
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------------
              // INFO TILE 2
              // ------------------------------------------------------
              _buildInfoTile(
                Icons.route_rounded,
                'Route-aware advisory',
                'Your location will help identify the relevant route region.',
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------------
              // INFO TILE 3
              // ------------------------------------------------------
              _buildInfoTile(
                Icons.security_rounded,
                'Privacy focused',
                'Your location is used only to support your travel advisory.',
              ),

              const Spacer(),

              // ------------------------------------------------------
              // ERROR MESSAGE
              // ------------------------------------------------------
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.mint,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        permissionPermanentlyDenied
                            ? Icons.settings_rounded
                            : Icons.info_outline_rounded,
                        color: AppTheme.forestGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color:
                                AppTheme.textPrimary,
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
                      onPressed: _openSettings,
                      child: const Text(
                        'OPEN APP SETTINGS',
                      ),
                    ),
                  ),

                if (permissionPermanentlyDenied)
                  const SizedBox(height: 12),
              ],

              // ------------------------------------------------------
              // ENABLE LOCATION BUTTON
              // ------------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _enableLocation,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.location_on_rounded,
                              size: 20,
                            ),
                            SizedBox(width: 9),
                            Text(
                              'ENABLE LOCATION',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------------------
              // REQUIRED LOCATION MESSAGE
              // ------------------------------------------------------
              Center(
                child: Text(
                  'Location access is required to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
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

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.mint,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.mint,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.forestGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color:
                        AppTheme.textSecondary,
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