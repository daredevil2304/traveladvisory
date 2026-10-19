import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';
import '../../notifications/widgets/commute_alert_banner.dart';

class RoutePoint {
  final String name;
  final double latitude;
  final double longitude;

  const RoutePoint({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() =>
      _TripDetailsScreenState();
}

class _TripDetailsScreenState
    extends State<TripDetailsScreen> {
  final TextEditingController _sourceController =
      TextEditingController();

  final TextEditingController _destinationController =
      TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String _role = 'traveler';

  String? _selectedSource;
  String? _selectedDestination;

  bool _locationWasDetected = false;
  bool _isAnalyzing = false;

  /*
   * Mumbai → Pune route points.
   *
   * These are user-facing route locations.
   * Final R1–R7 route-region mapping is handled
   * by the backend.
   */
  static const List<RoutePoint> routePoints = [
    RoutePoint(
      name: 'Mumbai / Sion',
      latitude: 19.04650,
      longitude: 72.86330,
    ),
    RoutePoint(
      name: 'Panvel',
      latitude: 18.98878,
      longitude: 73.11013,
    ),
    RoutePoint(
      name: 'Khalapur',
      latitude: 18.81670,
      longitude: 73.26670,
    ),
    RoutePoint(
      name: 'Khopoli',
      latitude: 18.78770,
      longitude: 73.34380,
    ),
    RoutePoint(
      name: 'Khandala',
      latitude: 18.77001,
      longitude: 73.38300,
    ),
    RoutePoint(
      name: 'Lonavala',
      latitude: 18.75460,
      longitude: 73.40620,
    ),
    RoutePoint(
      name: 'Kamshet',
      latitude: 18.76290,
      longitude: 73.55760,
    ),
    RoutePoint(
      name: 'Pune',
      latitude: 18.52050,
      longitude: 73.85650,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final arguments =
        ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map<String, dynamic>) {
      _role = arguments['role'] ?? 'traveler';

      final latitude = arguments['latitude'];
      final longitude = arguments['longitude'];

      if (latitude is num && longitude is num) {
        _setNearestSource(
          latitude.toDouble(),
          longitude.toDouble(),
        );
      }
    }

    _selectedSource ??= 'Mumbai / Sion';
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _setNearestSource(
    double latitude,
    double longitude,
  ) {
    RoutePoint nearestPoint = routePoints.first;

    double smallestDistance =
        _calculateDistance(
      latitude,
      longitude,
      nearestPoint.latitude,
      nearestPoint.longitude,
    );

    for (final point in routePoints.skip(1)) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < smallestDistance) {
        smallestDistance = distance;
        nearestPoint = point;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSource = nearestPoint.name;
      _locationWasDetected = true;
    });
  }

  void _swapRoutePoints() {
    setState(() {
      final temp = _selectedSource;
      _selectedSource = _selectedDestination;
      _selectedDestination = temp;
      _locationWasDetected = false;
    });
  }

  /*
   * Simple Haversine distance calculation.
   *
   * This is only used to select the nearest
   * user-facing route point.
   *
   * Final route-region mapping is handled
   * by FastAPI.
   */
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;

    final double dLat =
        (lat2 - lat1) * math.pi / 180;

    final double dLon =
        (lon2 - lon1) * math.pi / 180;

    final double lat1Rad =
        lat1 * math.pi / 180;

    final double lat2Rad =
        lat2 * math.pi / 180;

    final double a =
        math.sin(dLat / 2) *
            math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadius * c;
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime currentDate = DateTime(now.year, now.month, now.day);
    final DateTime maxAllowedDate = currentDate.add(const Duration(days: 7));

    DateTime initial = _selectedDate ?? currentDate;
    if (initial.isBefore(currentDate)) {
      initial = currentDate;
    } else if (initial.isAfter(maxAllowedDate)) {
      initial = maxAllowedDate;
    }

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: currentDate,
      lastDate: maxAllowedDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked =
        await showTimePicker(
      context: context,
      initialTime:
          _selectedTime ??
          TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // ============================================================
  // ANALYZE JOURNEY
  // ============================================================

  Future<void> _analyzeJourney() async {
    FocusScope.of(context).unfocus();

    if (_isAnalyzing) {
      return;
    }

    final bool isPlanner =
        _role == 'planner';

    // ----------------------------------------------------------
    // SOURCE / DESTINATION VALIDATION
    // ----------------------------------------------------------

    if (_selectedSource == null ||
        _selectedSource!.trim().isEmpty ||
        _selectedDestination == null ||
        _selectedDestination!.trim().isEmpty) {
      _showError(
        'Please select source and destination.',
      );
      return;
    }

    if (_selectedSource ==
        _selectedDestination) {
      _showError(
        'Source and destination cannot be the same.',
      );
      return;
    }

    // ----------------------------------------------------------
    // PLANNER DATE / TIME VALIDATION
    // ----------------------------------------------------------

    if (isPlanner &&
        (_selectedDate == null ||
            _selectedTime == null)) {
      _showError(
        'Please select your travel date and time.',
      );
      return;
    }

    // ----------------------------------------------------------
    // FIND SOURCE COORDINATES
    // ----------------------------------------------------------

    final RoutePoint? sourcePoint =
        _findRoutePoint(
      _selectedSource!,
    );

    if (sourcePoint == null) {
      _showError(
        'Unable to determine the coordinates of the selected source.',
      );
      return;
    }

    // ----------------------------------------------------------
    // TRAVELER
    // ----------------------------------------------------------
    //
    // Traveler reports are not present on this screen yet.
    // The backend requires a traveler report, so do not send
    // an invalid traveler request.
    //
    // The Traveler chatbot/report flow will provide this data.
    // ----------------------------------------------------------

    if (!isPlanner) {
      _showError(
        'Traveler condition reporting will be connected through the chatbot.',
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Automatically log commute check to learn traveler routine
      if (isPlanner && _selectedTime != null) {
        CommuteHabitService().logCheck(
          source: _selectedSource!,
          destination: _selectedDestination!,
          departureTime: _formatApiTime(_selectedTime!),
        );
      }

      final response =
          await ApiService.createTripRequest(
        role: 'planner',
        source: _selectedSource!,
        latitude:
            sourcePoint.latitude,
        longitude:
            sourcePoint.longitude,
        destination:
            _selectedDestination!,
        travelDate:
            _formatApiDate(
          _selectedDate!,
        ),
        travelTime:
            _formatApiTime(
          _selectedTime!,
        ),
      );

      final dynamic rawTripId =
          response['trip_id'];

      final int? tripId =
          _parseTripId(rawTripId);

      if (tripId == null) {
        throw ApiException(
          'The trip was created, but the server did not return a valid trip ID.',
        );
      }

      // ========================================================
      // STEP 2: ANALYZE TRIP
      // ========================================================

      final analysis =
          await ApiService.analyzeTrip(
        tripId: tripId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
      });

      // ========================================================
      // STEP 3: OPEN ANALYSIS SCREEN
      // ========================================================

      Navigator.pushNamed(
        context,
        '/journey-analysis',
        arguments: {
          'trip_id': tripId,
          'trip_response': response,
          'analysis': analysis,
          'role': _role,
          'source': _selectedSource!,
          'destination':
              _selectedDestination!,
          'latitude':
              sourcePoint.latitude,
          'longitude':
              sourcePoint.longitude,
          'travel_date':
              _formatApiDate(
            _selectedDate!,
          ),
          'travel_time':
              _formatApiTime(
            _selectedTime!,
          ),
        },
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
      });

      _showError(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
      });

      _showError(
        'Something went wrong while analyzing your journey.',
      );
    }
  }

  // ============================================================
  // ROUTE POINT LOOKUP
  // ============================================================

  RoutePoint? _findRoutePoint(
    String name,
  ) {
    for (final point in routePoints) {
      if (point.name == name) {
        return point;
      }
    }

    return null;
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatApiDate(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================

  String _formatApiTime(
    TimeOfDay time,
  ) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  // ============================================================
  // TRIP ID PARSER
  // ============================================================

  int? _parseTripId(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value == null) {
      return null;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isPlanner =
        _role == 'planner';

    return Scaffold(
      backgroundColor:
          AppTheme.lightMint,

      appBar: AppBar(
        backgroundColor:
            AppTheme.lightMint,
        elevation: 0,
        title:
            const Text('Trip Details'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: CommuteHabitService().hasUnreadAlertNotifier,
            builder: (context, hasAlert, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppTheme.darkNavy,
                    ),
                    tooltip: 'Commute Alerts',
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.commuteAlerts,
                      );
                    },
                  ),
                  if (hasAlert)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppTheme.crimsonRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.campaign_outlined,
              color: AppTheme.darkNavy,
            ),
            tooltip: 'Live Road Updates',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.liveRoadUpdates,
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppTheme.darkNavy,
            ),
            tooltip: 'Saved Reports',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.savedReports,
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            32,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Smart Commute Habit Alert Banner
              const CommuteAlertBanner(),

              // Live Road Updates Community Card
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.liveRoadUpdates,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Row(
                              children: [
                                Text(
                                  'Live Road Updates',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    child: Text(
                                      'ACTIVE 1H',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Check risky segments & traveler road reports without full analysis.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFCBD5E1),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Text(
                isPlanner
                    ? 'Plan your journey'
                    : 'Tell us about your journey',
                style:
                    Theme.of(context)
                        .textTheme
                        .headlineMedium,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                isPlanner
                    ? 'Choose where and when you plan to travel.'
                    : 'Choose your route to get a current travel safety assessment.',
                style:
                    Theme.of(context)
                        .textTheme
                        .bodyLarge,
              ),

              const SizedBox(
                height: 28,
              ),

              _buildSectionTitle(
                'FROM',
              ),

              const SizedBox(
                height: 10,
              ),

              _buildRouteDropdown(
                value:
                    _selectedSource,
                hint:
                    'Select starting point',
                icon:
                    Icons.my_location_rounded,
                onChanged:
                    (value) {
                  setState(() {
                    _selectedSource =
                        value;
                    _locationWasDetected =
                        false;
                  });
                },
              ),

              if (_locationWasDetected) ...[
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .gps_fixed_rounded,
                      size: 15,
                      color:
                          AppTheme.teal,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    const Text(
                      'Starting point detected from GPS',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppTheme.teal,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(
                height: 14,
              ),

              Center(
                child: InkWell(
                  onTap: _swapRoutePoints,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C1D4ED8),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: Color(0xFF1D4ED8),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Reverse Direction',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              _buildSectionTitle(
                'TO',
              ),

              const SizedBox(
                height: 10,
              ),

              _buildRouteDropdown(
                value:
                    _selectedDestination,
                hint:
                    'Select destination',
                icon:
                    Icons.location_on_rounded,
                onChanged:
                    (value) {
                  setState(() {
                    _selectedDestination =
                        value;
                  });
                },
              ),

              /*
               * DATE + TIME are only relevant
               * for Planner.
               *
               * Traveler = journey happening now.
               * Planner = future journey.
               */
              if (isPlanner) ...[
                const SizedBox(
                  height: 22,
                ),

                _buildSectionTitle(
                  'WHEN',
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildDateTimeCard(
                        icon: Icons
                            .calendar_today_rounded,
                        title: 'DATE',
                        value:
                            _selectedDate ==
                                    null
                                ? 'Select date'
                                : _formatDate(
                                    _selectedDate!,
                                  ),
                        onTap:
                            _selectDate,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child:
                          _buildDateTimeCard(
                        icon: Icons
                            .access_time_rounded,
                        title: 'TIME',
                        value:
                            _selectedTime ==
                                    null
                                ? 'Select time'
                                : _selectedTime!
                                    .format(
                                  context,
                                ),
                        onTap:
                            _selectTime,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(
                height: 28,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      AppTheme.white,
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  border:
                      Border.all(
                    color:
                        AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(
                        color:
                            AppTheme.mint,
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child: Icon(
                        isPlanner
                            ? Icons
                                .calendar_month_rounded
                            : Icons
                                .my_location_rounded,
                        color: AppTheme
                            .forestGreen,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    Expanded(
                      child: Text(
                        isPlanner
                            ? 'Your selected route and planned travel time will be analyzed using available travel-condition data.'
                            : 'Your current location, selected route, and current travel conditions will be used to assess your journey.',
                        style:
                            const TextStyle(
                          fontSize: 13,
                          color: AppTheme
                              .textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x301D4ED8),
                        blurRadius: 14,
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
                    onPressed: _isAnalyzing ? null : _analyzeJourney,
                    child: _isAnalyzing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPlanner
                                    ? Icons.calendar_month_rounded
                                    : Icons.explore_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPlanner
                                    ? 'ANALYZE JOURNEY'
                                    : 'ANALYZE CURRENT JOURNEY',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
  ) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppTheme.textSecondary,
      ),
    );
  }

  // ============================================================
  // ROUTE DROPDOWN
  // ============================================================

  Widget _buildRouteDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF1D4ED8),
        ),
      ),
      items: routePoints.map((point) {
        return DropdownMenuItem<String>(
          value: point.name,
          child: Text(
            point.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkNavy,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ============================================================
  // DATE / TIME CARD
  // ============================================================

  Widget _buildDateTimeCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration:
            BoxDecoration(
          color:
              AppTheme.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color:
                AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Icon(
              icon,
              color:
                  AppTheme.forestGreen,
              size: 22,
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
                color: AppTheme
                    .textSecondary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppTheme.darkNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPLAY DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}