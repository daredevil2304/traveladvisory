import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme.dart';

/// Comprehensive 24x7 Emergency & Highway SOS Directory Screen
/// for the Mumbai-Pune Expressway (NH-48 / Yashwantrao Chavan Expressway).
class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> with WidgetsBindingObserver {
  bool _isLoadingLocation = true;
  Position? _currentPosition;
  String? _nearestLandmark;
  int? _nearestChainageKm;
  double? _distanceToLandmarkKm;
  String _locationStatusMessage = 'Detecting current expressway position...';
  bool _needsPermission = false;
  bool _needsServiceEnable = false;
  bool _hasPromptedPermissionModal = false;

  // Expressway landmark chainage reference points (0km = Kalamboli/Panvel)
  static const List<_ExpresswayLandmark> _landmarks = [
    _ExpresswayLandmark('Kalamboli Junction (Start Point)', 19.0142, 73.1042, 0),
    _ExpresswayLandmark('Panvel Bypass Exit', 18.9888, 73.1101, 6),
    _ExpresswayLandmark('Khalapur Toll Plaza', 18.8167, 73.2667, 32),
    _ExpresswayLandmark('Khopoli Food Mall & Exit', 18.7877, 73.3438, 42),
    _ExpresswayLandmark('Bhor Ghat Base (Adoshi Tunnel)', 18.7801, 73.3550, 48),
    _ExpresswayLandmark('Khandala Ghat & Amrutanjan Point', 18.7700, 73.3830, 56),
    _ExpresswayLandmark('Lonavala Exit & Flyover', 18.7546, 73.4062, 64),
    _ExpresswayLandmark('Kamshet Tunnel', 18.7629, 73.5576, 78),
    _ExpresswayLandmark('Talegaon Toll Plaza', 18.7238, 73.6841, 95),
    _ExpresswayLandmark('Somatne Phata & Dehu Road Exit', 18.6942, 73.7258, 105),
    _ExpresswayLandmark('Kiwale / Wakad (Pune Exit)', 18.6478, 73.7582, 114),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Request permission immediately on screen launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLocation(mandatoryPrompt: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check automatically when user returns from phone settings or permission prompt
      _detectLocation(mandatoryPrompt: false);
    }
  }

  Future<void> _detectLocation({bool mandatoryPrompt = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _needsPermission = false;
      _needsServiceEnable = false;
      _locationStatusMessage = 'Detecting current expressway position...';
    });

    try {
      // 1. Check if device location services (GPS) are turned on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _needsServiceEnable = true;
            _locationStatusMessage = 'Device GPS is turned OFF. Turn ON for emergency rescue.';
          });
          if (mandatoryPrompt && !_hasPromptedPermissionModal) {
            _showMandatoryLocationModal(isServiceDisabled: true);
          }
        }
        return;
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Automatically trigger system permission dialog immediately
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
              _needsPermission = true;
              _locationStatusMessage = 'Location access is required for highway emergency dispatch.';
            });
            if (!_hasPromptedPermissionModal) {
              _showMandatoryLocationModal(isPermissionDenied: true);
            }
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _needsPermission = true;
            _locationStatusMessage = 'Location access is disabled in phone settings.';
          });
          if (!_hasPromptedPermissionModal) {
            _showMandatoryLocationModal(isDeniedForever: true);
          }
        }
        return;
      }

      // 3. Permission granted! Check last known position for instant readout (~10ms)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _applyPosition(lastKnown);
        setState(() {
          _isLoadingLocation = false;
        });
      }

      // 4. Fetch fresh high-precision GPS position
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        _applyPosition(fresh);
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted && _currentPosition == null) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatusMessage = 'GPS signal weak (check if indoors or near tunnel).';
        });
      }
    }
  }

  void _showMandatoryLocationModal({
    bool isServiceDisabled = false,
    bool isPermissionDenied = false,
    bool isDeniedForever = false,
  }) {
    if (!mounted) return;
    _hasPromptedPermissionModal = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return PopScope(
          canPop: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFDC2626),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'GPS Location Access Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isServiceDisabled
                      ? 'In a highway breakdown or medical emergency, your device GPS is required to detect your exact expressway kilometer stone (~km) so towing cranes and ambulances reach you immediately.'
                      : (isDeniedForever
                          ? 'Location permission is disabled for this app in your phone settings. Enable location access so highway patrol can pinpoint your vehicle on the expressway.'
                          : 'Emergency highway services require your live location to calculate the nearest milestone and dispatch roadside assistance.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (isServiceDisabled) {
                        await Geolocator.openLocationSettings();
                      } else if (isDeniedForever) {
                        await Geolocator.openAppSettings();
                      } else {
                        await Geolocator.requestPermission();
                      }
                      _detectLocation(mandatoryPrompt: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: Icon(
                      isServiceDisabled ? Icons.gps_fixed_rounded : Icons.lock_open_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isServiceDisabled
                          ? 'Turn ON Device GPS'
                          : (isDeniedForever ? 'Open Phone Settings' : 'Allow Location Access'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'I will locate mile marker manually',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
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

  void _applyPosition(Position pos) {
    _currentPosition = pos;
    _findNearestLandmark(pos.latitude, pos.longitude);
  }

  void _findNearestLandmark(double lat, double lon) {
    _ExpresswayLandmark? closest;
    double minDistance = double.infinity;

    for (final landmark in _landmarks) {
      final dist = _calculateDistanceKm(lat, lon, landmark.lat, landmark.lon);
      if (dist < minDistance) {
        minDistance = dist;
        closest = landmark;
      }
    }

    if (closest != null) {
      _nearestLandmark = closest.name;
      _nearestChainageKm = closest.chainageKm;
      _distanceToLandmarkKm = minDistance;
    }
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _makeCall(String title, String phone, String displayPhone) {
    HapticFeedback.heavyImpact();
    Clipboard.setData(ClipboardData(text: phone));

    _showDialerModal(title, phone, displayPhone);
  }

  void _showDialerModal(String title, String phone, String displayPhone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkNavy),
              ),
              const SizedBox(height: 14),
              // Horizontal number container with FittedBox so it NEVER wraps vertically
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayPhone,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'Phone number copied to clipboard!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Open your phone app and paste the number to place the call immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied $displayPhone to clipboard!'),
                        backgroundColor: const Color(0xFF1D4ED8),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Number Again', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyLocationToShare() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('🚨 MUMBAI-PUNE EXPRESSWAY EMERGENCY');
    sb.writeln('Corridor: Mumbai-Pune Expressway (NH-48)');
    if (_nearestLandmark != null) {
      sb.writeln('📍 Current Location: Near $_nearestLandmark (~${_nearestChainageKm}km)');
    }
    if (_currentPosition != null) {
      sb.writeln(
        '🗺️ GPS Coordinates: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
      );
      sb.writeln(
        '📌 Google Maps: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}',
      );
    }
    sb.writeln('Please dispatch emergency roadside assistance.');

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Emergency location copied! Paste in WhatsApp or SMS to send.'),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency SOS Directory',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '24x7 LIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          // 1. LIVE GPS & LOCATION SHARING CARD
          _buildLiveLocationCard(),

          const SizedBox(height: 16),

          // 2. QUICK GUIDE: WHICH NUMBER TO CALL WHEN (INTERACTIVE 1-TAP CARDS)
          _buildWhenToCallGuide(),

          const SizedBox(height: 14),

          // 3. PRIMARY 24x7 EMERGENCY HOTLINES (WITH WHEN TO CALL, COPY & CALL NOW)
          const _SectionHeader(
            title: 'PRIMARY 24x7 HIGHWAY HOTLINES',
            subtitle: 'Direct dispatch for ambulances, cranes, and police',
          ),
          const SizedBox(height: 8),

          _buildHotlineTile(
            title: 'IRB Expressway Control Room',
            subtitle: 'Ambulances, Heavy Towing Cranes & Expressway Patrol SOS',
            whenToCall: 'Car breakdown, puncture, engine stop, towing crane, or accident rescue',
            phone: '9822498224',
            displayPhone: '98224 98224',
            badge: 'TOWING & RESCUE',
            badgeColor: const Color(0xFFDC2626),
            isPrimary: true,
          ),
          _buildHotlineTile(
            title: 'National Highway Helpline (NHAI / MSRDC)',
            subtitle: 'Toll-free 24x7 Highway Emergency & Evacuation',
            whenToCall: 'Toll-free helpline (works even without mobile recharge balance)',
            phone: '1033',
            displayPhone: '1033 (Toll-Free)',
            badge: 'TOLL-FREE SOS',
            badgeColor: const Color(0xFF2563EB),
            isPrimary: true,
          ),
          _buildHotlineTile(
            title: 'State Highway Police HQ',
            subtitle: 'Maharashtra Police Highway Control Room & Highway Clearance',
            whenToCall: 'Police help, roadblock clearance, accident reporting, or rash driving',
            phone: '02025651515',
            displayPhone: '020-25651515',
            badge: 'POLICE HQ',
            badgeColor: const Color(0xFF059669),
            isPrimary: false,
          ),
          _buildHotlineTile(
            title: 'National Emergency Response (ERSS)',
            subtitle: 'Unified Single Emergency Number for Police, Medical & Fire',
            whenToCall: 'Life-threatening emergency, severe injury, or if other local lines are busy',
            phone: '112',
            displayPhone: '112',
            badge: 'UNIFIED 112',
            badgeColor: const Color(0xFFD97706),
            isPrimary: false,
          ),

          const SizedBox(height: 18),

          // 4. HIGHWAY BREAKDOWN SAFETY RULES (ALL 5 LIFE-SAVING STEPS)
          _buildBreakdownProtocolCard(),

          const SizedBox(height: 18),

          // 5. NEAREST TRAUMA CARE HOSPITALS
          const _SectionHeader(
            title: 'EMERGENCY TRAUMA HOSPITALS',
            subtitle: 'Stationed along key sectors of the expressway',
          ),
          const SizedBox(height: 8),

          _buildHospitalTile(
            name: 'MGM Hospital & Medical College',
            sector: 'Kamothe / Panvel Sector (~34km)',
            phone: '02227437900',
            displayPhone: '022-27437900',
            specialty: 'Level-1 Emergency Trauma & ICU',
          ),
          _buildHospitalTile(
            name: 'Jakhotia Nursing Home & Trauma',
            sector: 'Khopoli Phata (~70km • Ghat Base)',
            phone: '02192263300',
            displayPhone: '02192-263300',
            specialty: 'Ghat Entry Critical Resuscitation',
          ),
          _buildHospitalTile(
            name: 'Sanjeevani Hospital & Critical Care',
            sector: 'Lonavala Sector (~88km • Ghat Top)',
            phone: '02114273545',
            displayPhone: '02114-273545',
            specialty: 'Mountain Pass ICU & Cardiac Desk',
          ),
          _buildHospitalTile(
            name: 'Lokmanya Hospital for Trauma',
            sector: 'Nigdi / Pune Entry (~138km)',
            phone: '02030717500',
            displayPhone: '020-30717500',
            specialty: 'Advanced Orthopedic Trauma Center',
          ),

          const SizedBox(height: 18),

          // 6. AUTHORIZED SERVICE PLAZAS & TOWING HUBS
          const _SectionHeader(
            title: 'SERVICE PLAZAS & TOWING HUBS',
            subtitle: 'Fuel pumps, mechanics, puncture repair, and food courts',
          ),
          const SizedBox(height: 8),

          _buildPlazaTile(
            name: 'Khalapur Food Mall (Pune-bound)',
            chainage: '38km • Before Bhor Ghat',
            amenities: 'HPCL Fuel • EV Fast Chargers • Mechanics • Medical Aid • Food Courts',
          ),
          _buildPlazaTile(
            name: 'Ozarde Food Plaza (Mumbai-bound)',
            chainage: '78km • After Lonavala',
            amenities: 'BPCL Fuel • Heavy Towing Cranes • Puncture Repair • 24x7 Food Court',
          ),
          _buildPlazaTile(
            name: 'Urse Toll Plaza Service Bay',
            chainage: '118km • Near Pune Outer Ring',
            amenities: 'Concessionaire Recovery Bay • Emergency Crane Station • Basic Repair',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPACT & INTUITIVE WIDGET BUILDERS
  // ============================================================

  /// Interactive 1-tap guide showing which number to call for each emergency scenario
  Widget _buildWhenToCallGuide() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_center_rounded, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 8),
              Text(
                'Quick Guide: Which number to call?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInteractiveGuideRow(
            icon: Icons.car_crash_rounded,
            scenario: 'Breakdown / Flat Tire / Crane',
            authority: 'IRB Control (98224 98224)',
            phone: '9822498224',
            displayPhone: '98224 98224',
          ),
          _buildInteractiveGuideRow(
            icon: Icons.money_off_rounded,
            scenario: 'Free Call (No Mobile Balance)',
            authority: 'Toll-Free (1033)',
            phone: '1033',
            displayPhone: '1033',
          ),
          _buildInteractiveGuideRow(
            icon: Icons.local_police_rounded,
            scenario: 'Police Help / Roadblock / Crash',
            authority: 'Highway Police (020-25651515)',
            phone: '02025651515',
            displayPhone: '020-25651515',
          ),
          _buildInteractiveGuideRow(
            icon: Icons.emergency_rounded,
            scenario: 'Severe Injury / Ambulance',
            authority: 'Dial 112 (Unified)',
            phone: '112',
            displayPhone: '112',
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveGuideRow({
    required IconData icon,
    required String scenario,
    required String authority,
    required String phone,
    required String displayPhone,
  }) {
    return InkWell(
      onTap: () => _makeCall(scenario, phone, displayPhone),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF15803D)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                scenario,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authority,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.call_rounded, size: 11, color: Color(0xFF166534)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR LIVE HIGHWAY LOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      'Share this when calling for patrol or towing',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Refresh GPS',
                onPressed: _detectLocation,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _isLoadingLocation
                ? const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Finding nearest expressway milestone...',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentPosition != null) ...[
                        Text(
                          _nearestLandmark != null
                              ? '📍 Near $_nearestLandmark (~${_nearestChainageKm}km${_distanceToLandmarkKm != null ? ', ${_distanceToLandmarkKm!.toStringAsFixed(1)}km away' : ''})'
                              : '📍 Mumbai-Pune Expressway Corridor',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° E',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _locationStatusMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_needsPermission) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final p = await Geolocator.requestPermission();
                              if (p == LocationPermission.deniedForever) {
                                await Geolocator.openAppSettings();
                              }
                              _detectLocation(mandatoryPrompt: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 14),
                            label: const Text('Allow GPS Location Access', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
                        if (_needsServiceEnable) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Geolocator.openLocationSettings();
                              _detectLocation(mandatoryPrompt: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                            label: const Text('Turn ON Device GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          // User-friendly copy button (WhatsApp / SMS)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyLocationToShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text(
                'Copy Location to Share (WhatsApp / SMS)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact hotline tile with title, subtitle, when-to-call, horizontal phone number, Copy button, and Call Now button
  Widget _buildHotlineTile({
    required String title,
    required String subtitle,
    required String whenToCall,
    required String phone,
    required String displayPhone,
    required String badge,
    required Color badgeColor,
    required bool isPrimary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFFFFBFB) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isPrimary ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _makeCall(title, phone, displayPhone),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isPrimary ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: isPrimary ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              // Center Column: Title, Subtitle, When to Call, and HORIZONTAL PHONE NUMBER
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    // Specific "When to call" instruction
                    Text(
                      'When to call: $whenToCall',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Strictly horizontal single-line number (NEVER WRAPS!)
                    Text(
                      displayPhone,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isPrimary ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Copy Number',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $displayPhone to clipboard!'),
                      backgroundColor: const Color(0xFF1D4ED8),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              // Compact "Call" action pill without awkward gap before label
              ElevatedButton(
                onPressed: () => _makeCall(title, phone, displayPhone),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrimary ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Call',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact breakdown safety card with all 5 safety steps
  Widget _buildBreakdownProtocolCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 7),
              Text(
                'Expressway Breakdown Safety Rules',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactStep('1', 'Pull immediately to extreme left hard shoulder. Never stop in active traffic lanes.'),
          _buildCompactStep('2', 'Turn ON 4-way hazard lights immediately to warn approaching vehicles.'),
          _buildCompactStep('3', 'Step out and stand behind the metal crash barrier. Do not wait inside the car!'),
          _buildCompactStep('4', 'Note nearest yellow kilometer stone on the divider to give exact location.'),
          _buildCompactStep('5', 'Call IRB Control (98224 98224) or Highway Patrol (1033) for free safety escort & towing.'),
        ],
      ),
    );
  }

  Widget _buildCompactStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF78350F),
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact trauma hospital tile with both Copy and Call buttons
  Widget _buildHospitalTile({
    required String name,
    required String sector,
    required String phone,
    required String displayPhone,
    required String specialty,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _makeCall(name, phone, displayPhone),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626), size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$sector • $specialty',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    // Horizontal phone number
                    Text(
                      displayPhone,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 17, color: Color(0xFF64748B)),
                tooltip: 'Copy Hospital Number',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $name number ($displayPhone) to clipboard!'),
                      backgroundColor: const Color(0xFF1D4ED8),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => _makeCall(name, phone, displayPhone),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 12),
                    SizedBox(width: 4),
                    Text('Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact service plaza tile
  Widget _buildPlazaTile({
    required String name,
    required String chainage,
    required String amenities,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_rounded, color: Color(0xFF2563EB), size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ),
                    Text(
                      chainage,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  amenities,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF475569),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ExpresswayLandmark {
  final String name;
  final double lat;
  final double lon;
  final int chainageKm;

  const _ExpresswayLandmark(this.name, this.lat, this.lon, this.chainageKm);
}
