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

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  bool _isLoadingLocation = true;
  Position? _currentPosition;
  String? _nearestLandmark;
  int? _nearestChainageKm;
  double? _distanceToLandmarkKm;

  // Expressway landmark chainage reference points (KM 0 = Kalamboli/Panvel)
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
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _findNearestLandmark(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
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

  void _copyLocationToClipboard() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('🚨 EXPRESSWAY EMERGENCY SOS');
    sb.writeln('Corridor: Mumbai-Pune Expressway (NH-48)');
    if (_nearestLandmark != null) {
      sb.writeln('Estimated Location: Near $_nearestLandmark (~KM $_nearestChainageKm)');
    }
    if (_currentPosition != null) {
      sb.writeln(
        'GPS Coordinates: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
      );
      sb.writeln(
        'Google Maps: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}',
      );
    }
    sb.writeln('Please dispatch emergency roadside assistance.');

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied your emergency location & GPS coordinates to clipboard!'),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyNumber(String label, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label ($phone) to clipboard! Paste in phone dialer.'),
        backgroundColor: const Color(0xFF1E293B),
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, size: 14, color: Colors.white),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. LIVE GPS & LOCATION DISPATCH CARD
          _buildLiveLocationCard(),

          const SizedBox(height: 18),

          // 2. PRIMARY 24x7 DISPATCH HOTLINES
          const _SectionHeader(
            title: 'PRIMARY DISPATCH HOTLINES (24x7)',
            subtitle: 'Immediate rescue, ambulances, towing cranes, and highway police',
          ),
          const SizedBox(height: 10),

          _buildHotlineCard(
            title: 'IRB Expressway Central Control Room',
            subtitle: 'Ambulance, Heavy Towing Crane, Hydraulic Rescue & Patrol',
            phone: '9822498224',
            displayPhone: '98224 98224',
            badge: 'PRIMARY EXPRESSWAY DISPATCH',
            badgeColor: const Color(0xFFDC2626),
            isPrimary: true,
          ),
          const SizedBox(height: 10),

          _buildHotlineCard(
            title: 'National Highway Helpline (NHAI / MSRDC)',
            subtitle: 'Toll-free 24x7 Emergency, Accident Dispatch & Route Evacuation',
            phone: '1033',
            displayPhone: '1033 (Toll-Free)',
            badge: 'ALL-INDIA HIGHWAY SOS',
            badgeColor: const Color(0xFF2563EB),
            isPrimary: true,
          ),
          const SizedBox(height: 10),

          _buildHotlineCard(
            title: 'Maharashtra Highway Police Control HQ',
            subtitle: 'State Police Control Room, Accident Reporting & Highway Clearance',
            phone: '02025651515',
            displayPhone: '020-25651515',
            badge: 'TRAFFIC POLICE HQ',
            badgeColor: const Color(0xFF059669),
            isPrimary: false,
          ),
          const SizedBox(height: 10),

          _buildHotlineCard(
            title: 'National Emergency Response (ERSS)',
            subtitle: 'Unified Single Emergency Number for Police, Fire & Medical',
            phone: '112',
            displayPhone: '112',
            badge: 'UNIFIED EMERGENCY',
            badgeColor: const Color(0xFFD97706),
            isPrimary: false,
          ),

          const SizedBox(height: 24),

          // 3. VEHICLE BREAKDOWN & CRASH SURVIVAL RULES
          const _SectionHeader(
            title: 'EXPRESSWAY BREAKDOWN PROTOCOL',
            subtitle: 'Crucial life-saving steps if your vehicle stops on the highway',
          ),
          const SizedBox(height: 10),
          _buildBreakdownProtocolCard(),

          const SizedBox(height: 24),

          // 4. NEAREST TRAUMA CARE HOSPITALS
          const _SectionHeader(
            title: 'STRATEGIC TRAUMA HOSPITALS ALONG CORRIDOR',
            subtitle: 'Direct hospital emergency desks stationed across key sectors',
          ),
          const SizedBox(height: 10),

          _buildHospitalCard(
            name: 'MGM Hospital & Medical College',
            sector: 'Kamothe / Panvel Sector (~KM 34)',
            phone: '02227437900',
            displayPhone: '022-27437900',
            specialty: 'Level-1 24x7 Emergency Trauma & Neurosurgery',
          ),
          const SizedBox(height: 10),

          _buildHospitalCard(
            name: 'Jakhotia Nursing Home & Trauma Center',
            sector: 'Khopoli Phata (~KM 70 • Base of Bhor Ghat)',
            phone: '02192263300',
            displayPhone: '02192-263300',
            specialty: 'Immediate Ghat Entry Critical Resuscitation',
          ),
          const SizedBox(height: 10),

          _buildHospitalCard(
            name: 'Sanjeevani Hospital & Critical Care',
            sector: 'Lonavala Sector (~KM 88 • Summit of Ghat)',
            phone: '02114273545',
            displayPhone: '02114-273545',
            specialty: 'Mountain Pass Emergency ICU & Cardiac Support',
          ),
          const SizedBox(height: 10),

          _buildHospitalCard(
            name: 'Lokmanya Hospital for Trauma',
            sector: 'Nigdi / Pune Entry (~KM 138)',
            phone: '02030717500',
            displayPhone: '020-30717500',
            specialty: 'Advanced Orthopedic Trauma & ICU Center',
          ),

          const SizedBox(height: 24),

          // 5. AUTHORIZED SERVICE PLAZAS & TOWING HUBS
          const _SectionHeader(
            title: 'AUTHORIZED SERVICE PLAZAS & WORKSHOPS',
            subtitle: 'Fuel pumps, EV fast charging, puncture repair, and food courts',
          ),
          const SizedBox(height: 10),

          _buildPlazaCard(
            name: 'Khalapur Food Mall (Pune-bound)',
            chainage: 'KM 38 • Before Bhor Ghat',
            amenities: 'HPCL Fuel Station • Tata Power EV DC Chargers • Mechanics & Puncture • Medical First Aid • Food Courts',
          ),
          const SizedBox(height: 10),

          _buildPlazaCard(
            name: 'Ozarde Food Plaza (Mumbai-bound)',
            chainage: 'KM 78 • After Lonavala',
            amenities: 'BPCL Fuel Station • Heavy Towing Cranes • Tire Alignment • Restrooms • 24x7 Food Court',
          ),
          const SizedBox(height: 10),

          _buildPlazaCard(
            name: 'Urse Toll Plaza Service Bay',
            chainage: 'KM 118 • Near Pune Outer Ring',
            amenities: 'Expressway Concessionaire Recovery Bay • Emergency Crane Station • Basic Repair',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGET BUILDERS
  // ============================================================

  Widget _buildLiveLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1ADC2626),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CURRENT LOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Give this location when calling dispatchers',
                      style: TextStyle(
                        fontSize: 12,
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _isLoadingLocation
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Detecting nearest expressway landmark...',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nearestLandmark != null
                            ? '📍 Near $_nearestLandmark (~KM $_nearestChainageKm${_distanceToLandmarkKm != null ? ', ${_distanceToLandmarkKm!.toStringAsFixed(1)} km away' : ''})'
                            : '📍 Mumbai-Pune Expressway Corridor',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentPosition != null
                            ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° E (±${_currentPosition!.accuracy.toStringAsFixed(0)}m accuracy)'
                            : 'Enable GPS location access for real-time highway chainage',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyLocationToClipboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                'Copy Location Text for Dispatcher',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineCard({
    required String title,
    required String subtitle,
    required String phone,
    required String displayPhone,
    required String badge,
    required Color badgeColor,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppTheme.darkNavy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.call_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Text(
                        displayPhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _copyNumber(title, phone),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrimary ? const Color(0xFFDC2626) : AppTheme.darkNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownProtocolCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 8),
              Text(
                'Safety Steps for Highway Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProtocolStep(
            step: '1',
            text: 'Pull immediately to the extreme left hard shoulder. Never stop in active traffic lanes or inside tunnels.',
          ),
          _buildProtocolStep(
            step: '2',
            text: 'Turn ON 4-way hazard lights immediately to warn approaching high-speed highway traffic.',
          ),
          _buildProtocolStep(
            step: '3',
            text: 'CRITICAL: DO NOT remain seated inside a stationary car! Step out from the left door and stand behind the metal crash barrier.',
          ),
          _buildProtocolStep(
            step: '4',
            text: 'Look for the nearest yellow KM stone on the divider and note your direction (towards Pune or towards Mumbai).',
          ),
          _buildProtocolStep(
            step: '5',
            text: 'Call IRB Control Room (98224 98224) or Highway Patrol (1033) for free safety escort and towing assistance.',
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolStep({required String step, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF78350F),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalCard({
    required String name,
    required String sector,
    required String phone,
    required String displayPhone,
    required String specialty,
  }) {
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
              const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sector,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 2),
          Text(
            specialty,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  displayPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyNumber(name, phone),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlazaCard({
    required String name,
    required String chainage,
    required String amenities,
  }) {
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
              const Icon(Icons.local_gas_station_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chainage,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 4),
          Text(
            amenities,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
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
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF475569),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
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
