import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/commute_habit_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() =>
      _ChatbotScreenState();
}

class _ChatbotScreenState
    extends State<ChatbotScreen> {
  final TextEditingController
      _messageController =
      TextEditingController();

  final ScrollController
      _scrollController =
      ScrollController();

  final List<_ChatMessage> _messages =
      [];

  String _role = 'traveler';

  double? _latitude;
  double? _longitude;

  String? _source;
  String? _destination;

  String? _travelDate;
  String? _travelTime;

  String? _rain;
  String? _visibility;
  String? _fog;
  String? _unusualConditions;
  String? _traffic;

  _ConversationStep _step =
      _ConversationStep.confirmSource;

  bool _isTyping = false;
  bool _journeyReady = false;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;
  bool _isCollectingLiveUpdates = false;
  Map<String, dynamic>? _tripAnalysis;

  int? _tripId;

  // ============================================================
  // ROUTE POINTS
  // ============================================================

  static const List<_RoutePoint>
      _routePoints = [
    _RoutePoint(
      name: 'Mumbai',
      displayName: 'Mumbai / Sion',
      latitude: 19.04650,
      longitude: 72.86330,
    ),
    _RoutePoint(
      name: 'Panvel',
      displayName: 'Panvel',
      latitude: 18.98878,
      longitude: 73.11013,
    ),
    _RoutePoint(
      name: 'Khalapur',
      displayName: 'Khalapur',
      latitude: 18.81670,
      longitude: 73.26670,
    ),
    _RoutePoint(
      name: 'Khopoli',
      displayName: 'Khopoli',
      latitude: 18.78770,
      longitude: 73.34380,
    ),
    _RoutePoint(
      name: 'Khandala',
      displayName: 'Khandala',
      latitude: 18.77001,
      longitude: 73.38300,
    ),
    _RoutePoint(
      name: 'Lonavala',
      displayName: 'Lonavala',
      latitude: 18.75460,
      longitude: 73.40620,
    ),
    _RoutePoint(
      name: 'Kamshet',
      displayName: 'Kamshet',
      latitude: 18.76290,
      longitude: 73.55760,
    ),
    _RoutePoint(
      name: 'Pune',
      displayName: 'Pune',
      latitude: 18.52050,
      longitude: 73.85650,
    ),
  ];

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_messages.isNotEmpty) {
      return;
    }

    final arguments =
        ModalRoute.of(context)
            ?.settings
            .arguments;

    if (arguments
        is Map<String, dynamic>) {
      final role =
          arguments['role'];

      if (role is String &&
          role.isNotEmpty) {
        _role = role;
      }

      final latitude =
          arguments['latitude'];

      final longitude =
          arguments['longitude'];

      if (latitude is num) {
        _latitude =
            latitude.toDouble();
      }

      if (longitude is num) {
        _longitude =
            longitude.toDouble();
      }
    }

    _startConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // START CONVERSATION
  // ============================================================

  void _startConversation() {
    final bool isPlanner =
        _role == 'planner';

    _addBotMessage(
      'Hi! I am your Mumbai Pune Travel Advisor.',
    );

    _addBotMessage(
      isPlanner
          ? 'I will help you plan your journey using the requested travel time and conditions along the route.'
          : 'I will help you understand the current conditions along your journey.',
    );

    if (_latitude == null ||
        _longitude == null) {
      _step = _ConversationStep.manualSource;
      _addBotMessage(
        'Please select your starting location along the corridor.',
        quickReplies: _routePoints
            .map((item) => item.displayName)
            .toList(),
      );
      return;
    }

    final _RoutePoint
        nearestPoint =
        _getNearestRoutePoint(
      _latitude!,
      _longitude!,
    );

    /*
     * IMPORTANT:
     *
     * "Current Location" is only conversational
     * wording. It is NEVER sent to the backend.
     *
     * Backend receives canonical route names:
     * Mumbai, Panvel, Khalapur, etc.
     */
    _source =
        nearestPoint.name;

    _addBotMessage(
      'I have detected your current location near ${nearestPoint.displayName}.',
    );

    _addBotMessage(
      'Would you like to use this as your starting point?',
      quickReplies: const [
        'Yes',
        'Change source',
      ],
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void _sendMessage() {
    final String message =
        _messageController.text.trim();

    if (message.isEmpty ||
        _isTyping ||
        _isAnalyzing) {
      return;
    }

    _messageController.clear();

    _addUserMessage(message);

    /*
     * After analysis, the chatbot remains active.
     * User can ask follow-up questions instead
     * of being forced onto another screen.
     */
    if (_isCollectingLiveUpdates) {
      _handleLiveUpdateMessage(message);
      return;
    }

    if (_analysisComplete) {
      _handlePostAnalysisMessage(
        message,
      );
      return;
    }

    if (_journeyReady) {
      _analyzeJourney();
      return;
    }

    _processMessage(message);
  }

  // ============================================================
  // QUICK REPLY
  // ============================================================

  void _selectQuickReply(
    String value,
  ) {
    if (_isTyping ||
        _isAnalyzing) {
      return;
    }

    if (value.contains('Calendar')) {
      _pickPlannerDate();
      return;
    }

    if (value.contains('Clock')) {
      _pickPlannerTime();
      return;
    }

    _addUserMessage(value);

    if (_isCollectingLiveUpdates) {
      _handleLiveUpdateMessage(value);
      return;
    }

    if (_analysisComplete) {
      _handlePostAnalysisMessage(
        value,
      );
      return;
    }

    if (_journeyReady) {
      _analyzeJourney();
      return;
    }

    _processMessage(value);
  }

  // ============================================================
  // PROCESS MESSAGE
  // ============================================================

  void _processMessage(
    String message,
  ) {
    final String normalized =
        message
            .toLowerCase()
            .trim();

    switch (_step) {
      case _ConversationStep
          .confirmSource:
        _handleSourceConfirmation(
          normalized,
        );
        break;

      case _ConversationStep
          .manualSource:
        _handleManualSource(
          message,
        );
        break;

      case _ConversationStep
          .destination:
        _handleDestination(
          message,
        );
        break;

      case _ConversationStep
          .plannerDate:
        _handlePlannerDate(
          message,
        );
        break;

      case _ConversationStep
          .plannerTime:
        _handlePlannerTime(
          message,
        );
        break;

      case _ConversationStep
          .travelerRain:
        _handleTravelerRain(
          message,
        );
        break;

      case _ConversationStep
          .travelerVisibility:
        _handleTravelerVisibility(
          message,
        );
        break;

      case _ConversationStep
          .travelerFog:
        _handleTravelerFog(
          message,
        );
        break;

      case _ConversationStep
          .travelerUnusual:
        _handleTravelerUnusual(
          message,
        );
        break;

      case _ConversationStep
          .travelerTraffic:
        _handleTravelerTraffic(
          message,
        );
        break;

      case _ConversationStep.ready:
        break;

      case _ConversationStep.liveUpdateRain:
      case _ConversationStep.liveUpdateVisibility:
      case _ConversationStep.liveUpdateHazards:
      case _ConversationStep.liveUpdateTraffic:
        _handleLiveUpdateMessage(message);
        break;

      case _ConversationStep.postAnalysis:
        _handlePostAnalysisMessage(message);
        break;
    }
  }

  // ============================================================
  // SOURCE CONFIRMATION
  // ============================================================

  void _handleSourceConfirmation(
    String message,
  ) {
    final bool accepted =
        message == 'yes' ||
        message.contains('yes');

    if (accepted) {
      _askDestination();
      return;
    }

    if (message.contains(
          'change',
        ) ||
        message.contains(
          'different',
        )) {
      _addBotMessage(
        'Sure. Which starting location would you like to use?',
        quickReplies:
            _routePoints
                .map(
                  (point) =>
                      point.displayName,
                )
                .toList(),
      );

      _step =
          _ConversationStep
              .manualSource;

      return;
    }

    _addBotMessage(
      'Would you like to use the detected starting point?',
      quickReplies: const [
        'Yes',
        'Change source',
      ],
    );
  }

  // ============================================================
  // MANUAL SOURCE
  // ============================================================

  void _handleManualSource(
    String message,
  ) {
    final _RoutePoint? point =
        _findRoutePoint(message);

    if (point == null) {
      _addBotMessage(
        'Please choose a location on the Mumbai Pune route.',
        quickReplies:
            _routePoints
                .map(
                  (item) =>
                      item.displayName,
                )
                .toList(),
      );
      return;
    }

    _source =
        point.name;
    _latitude =
        point.latitude;
    _longitude =
        point.longitude;

    _addBotMessage(
      'Sure, we will start from ${point.displayName}.',
    );

    _askDestination();
  }

  // ============================================================
  // DESTINATION
  // ============================================================

  void _askDestination() {
    _step =
        _ConversationStep
            .destination;

    final String src = (_source ?? '').toLowerCase().trim();

    final destinationOptions = _routePoints
        .where((point) {
          final pName = point.name.toLowerCase().trim();
          final pDisplay = point.displayName.toLowerCase().trim();
          if (src.isEmpty) return true;
          if (pName == src || pDisplay == src) return false;
          if (src.contains(pName) || pName.contains(src)) return false;
          if ((src.contains('mumb') || src.contains('sion')) &&
              (pName.contains('mumb') || pDisplay.contains('mumb') || pDisplay.contains('sion'))) {
            return false;
          }
          if (src.contains('pun') && (pName.contains('pun') || pDisplay.contains('pun'))) {
            return false;
          }
          return true;
        })
        .map((point) => point.displayName)
        .toList();

    _addBotMessage(
      'Great. Where are you heading?',
      quickReplies: destinationOptions,
    );
  }

  void _handleDestination(
    String message,
  ) {
    final _RoutePoint? point =
        _findRoutePoint(message);

    final String src = (_source ?? '').toLowerCase().trim();
    final destinationOptions = _routePoints
        .where((p) {
          final pName = p.name.toLowerCase().trim();
          final pDisplay = p.displayName.toLowerCase().trim();
          if (src.isEmpty) return true;
          if (pName == src || pDisplay == src) return false;
          if (src.contains(pName) || pName.contains(src)) return false;
          if ((src.contains('mumb') || src.contains('sion')) &&
              (pName.contains('mumb') || pDisplay.contains('mumb') || pDisplay.contains('sion'))) {
            return false;
          }
          if (src.contains('pun') && (pName.contains('pun') || pDisplay.contains('pun'))) {
            return false;
          }
          return true;
        })
        .map((p) => p.displayName)
        .toList();

    if (point == null) {
      _addBotMessage(
        'Please choose a supported Mumbai Pune route destination.',
        quickReplies: destinationOptions,
      );
      return;
    }

    if (_source ==
        point.name) {
      _addBotMessage(
        'Your source and destination are the same. Please choose another destination.',
      );
      return;
    }

    _destination =
        point.name;

    final bool isPlanner =
        _role == 'planner';

    if (isPlanner) {
      _step =
          _ConversationStep
              .plannerDate;

      _addBotMessage(
        'Got it. When are you planning to travel?',
        quickReplies: const [
          '📅 Choose Date on Calendar',
          'Same Day',
          'Tomorrow',
        ],
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _ConversationStep.plannerDate) {
          _pickPlannerDate();
        }
      });

      return;
    }

    // Traveler: Directly trigger journey analysis and show report
    _analyzeJourney();
  }

  // ============================================================
  // PLANNER DATE & CALENDAR PICKER
  // ============================================================

  Future<void> _pickPlannerDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.forestGreen,
              onPrimary: AppTheme.white,
              onSurface: AppTheme.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String formattedDate = _formatDate(picked);
      _addUserMessage(formattedDate);
      _travelDate = formattedDate;

      _step = _ConversationStep.plannerTime;

      _addBotMessage(
        'Travel date set to $formattedDate. Roughly what time would you like to depart?',
        quickReplies: const [
          '⏰ Pick Time on Clock',
          'Morning (08:00)',
          'Afternoon (14:00)',
          'Evening (18:00)',
          'Night (21:00)',
        ],
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _ConversationStep.plannerTime) {
          _pickPlannerTime();
        }
      });
    }
  }

  void _handlePlannerDate(
    String message,
  ) {
    if (message.toLowerCase().contains('calendar')) {
      _pickPlannerDate();
      return;
    }

    final String? date =
        _parsePlannerDate(
      message,
    );

    if (date == null) {
      _addBotMessage(
        'Please specify your travel date using the calendar or choose Tomorrow / Same Day.',
        quickReplies: const [
          '📅 Choose Date on Calendar',
          'Same Day',
          'Tomorrow',
        ],
      );
      return;
    }

    _travelDate = date;

    _step =
        _ConversationStep
            .plannerTime;

    _addBotMessage(
      'Travel date set to $date. Roughly what time would you like to depart?',
      quickReplies: const [
        '⏰ Pick Time on Clock',
        'Morning (08:00)',
        'Afternoon (14:00)',
        'Evening (18:00)',
        'Night (21:00)',
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step == _ConversationStep.plannerTime) {
        _pickPlannerTime();
      }
    });
  }

  // ============================================================
  // PLANNER TIME & CLOCK PICKER
  // ============================================================

  Future<void> _pickPlannerTime() async {
    final TimeOfDay nowTime = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: nowTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.forestGreen,
              onPrimary: AppTheme.white,
              onSurface: AppTheme.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String hour = picked.hour.toString().padLeft(2, '0');
      final String minute = picked.minute.toString().padLeft(2, '0');
      final String formattedTime = '$hour:$minute:00';
      final String displayTime = '$hour:$minute';
      _addUserMessage(displayTime);
      _travelTime = formattedTime;

      _analyzeJourney();
    }
  }

  void _handlePlannerTime(
    String message,
  ) {
    if (message.toLowerCase().contains('clock')) {
      _pickPlannerTime();
      return;
    }

    final String? time =
        _parsePlannerTime(
      message,
    );

    if (time == null) {
      _addBotMessage(
        'Please pick a departure time on the clock / select one below.',
        quickReplies: const [
          '⏰ Pick Time on Clock',
          'Morning (08:00)',
          'Afternoon (14:00)',
          'Evening (18:00)',
          'Night (21:00)',
        ],
      );
      return;
    }

    _travelTime = time;

    _analyzeJourney();
  }

  // ============================================================
  // TRAVELER RAIN
  // ============================================================

  void _handleTravelerRain(
    String message,
  ) {
    if (message.toLowerCase().contains('skip') ||
        message.toLowerCase().contains('analyze')) {
      _analyzeJourney();
      return;
    }

    _rain =
        message.trim();

    _step =
        _ConversationStep
            .travelerVisibility;

    _addBotMessage(
      'How is the visibility along the route?',
      quickReplies: const [
        'Clear',
        'Slightly reduced',
        'Moderately reduced',
        'Poor',
        'Skip to Analysis',
      ],
    );
  }

  // ============================================================
  // TRAVELER VISIBILITY
  // ============================================================

  void _handleTravelerVisibility(
    String message,
  ) {
    if (message.toLowerCase().contains('skip') ||
        message.toLowerCase().contains('analyze')) {
      _analyzeJourney();
      return;
    }

    _visibility =
        message.trim();

    _step =
        _ConversationStep
            .travelerFog;

    _addBotMessage(
      'Are you noticing any fog / mist?',
      quickReplies: const [
        'None',
        'Light mist',
        'Dense fog',
        'Skip to Analysis',
      ],
    );
  }

  // ============================================================
  // TRAVELER FOG
  // ============================================================

  void _handleTravelerFog(
    String message,
  ) {
    if (message.toLowerCase().contains('skip') ||
        message.toLowerCase().contains('analyze')) {
      _analyzeJourney();
      return;
    }

    _fog =
        message.trim();

    _step =
        _ConversationStep
            .travelerUnusual;

    _addBotMessage(
      'Any unusual road conditions observed?',
      quickReplies: const [
        'Nothing unusual',
        'Slippery road',
        'Waterlogging',
        'Landslide / Rockfall',
        'Debris',
        'Skip to Analysis',
      ],
    );
  }

  // ============================================================
  // TRAVELER UNUSUAL CONDITIONS
  // ============================================================

  void _handleTravelerUnusual(
    String message,
  ) {
    if (message.toLowerCase().contains('skip') ||
        message.toLowerCase().contains('analyze')) {
      _analyzeJourney();
      return;
    }

    _unusualConditions =
        _normalizeUnusualCondition(
      message,
    );

    _step =
        _ConversationStep
            .travelerTraffic;

    _addBotMessage(
      'How does the traffic appear?',
      quickReplies: const [
        'Free flow',
        'Moderate',
        'Heavy',
        'Analyze Route',
      ],
    );
  }

  // ============================================================
  // TRAVELER TRAFFIC
  // ============================================================

  void _handleTravelerTraffic(
    String message,
  ) {
    if (!message.toLowerCase().contains('analyze')) {
      _traffic =
          _normalizeTraffic(
        message,
      );
    }

    _analyzeJourney();
  }

  // ============================================================
  // READY
  // ============================================================


  // ============================================================
// ANALYZE JOURNEY
// ============================================================

Future<void> _analyzeJourney() async {
  if (_isAnalyzing) {
    return;
  }

  if (_latitude == null || _longitude == null) {
    final _RoutePoint? point = _source != null ? _findRoutePoint(_source!) : null;
    if (point != null) {
      _latitude = point.latitude;
      _longitude = point.longitude;
    } else {
      _latitude = 18.9388;
      _longitude = 72.8354;
    }
  }

  if (_source == null || _source!.trim().isEmpty) {
    _showError('Please provide a starting location.');
    return;
  }

  if (_destination == null || _destination!.trim().isEmpty) {
    _showError('Please provide a destination.');
    return;
  }

  final bool isPlanner = _role == 'planner';

  if (isPlanner &&
      (_travelDate == null || _travelTime == null)) {
    _showError(
      'Travel date and time are required for a planned journey.',
    );
    return;
  }

  FocusScope.of(context).unfocus();

  setState(() {
    _isAnalyzing = true;
  });

  _addBotMessage(
    'I’m analyzing your journey now. I’ll check each relevant route segment rather than looking only at your source and destination.',
  );

  try {
    final bool hasTravelerData = !isPlanner && (
        _rain != null || _visibility != null || _fog != null ||
        _unusualConditions != null || _traffic != null
    );

    final Map<String, dynamic>? travelerReport = hasTravelerData
        ? {
            'rain': _rain,
            'visibility': _visibility,
            'fog': _fog,
            'unusual_conditions': _unusualConditions,
            'traffic': _traffic,
          }
        : null;

    // Automatically record commute check to learn habit patterns
    CommuteHabitService().logCheck(
      source: _source!,
      destination: _destination!,
      departureTime: _travelTime,
    );

    final Map<String, dynamic> response =
        await ApiService.createTripRequest(
      role: _role,
      source: _source!,
      latitude: _latitude!,
      longitude: _longitude!,
      destination: _destination!,
      travelDate: isPlanner ? _travelDate : null,
      travelTime: isPlanner ? _travelTime : null,
      travelerReport: travelerReport,
    );

    final int? tripId = _parseTripId(
      response['trip_id'],
    );

    if (tripId == null) {
      throw ApiException(
        'The server did not return a valid trip ID.',
      );
    }

    _tripId = tripId;
final dynamic analysis = await ApiService.analyzeTrip(
  tripId: tripId,
);

final Map<String, dynamic> analysisData =
    analysis is Map<String, dynamic>
        ? analysis
        : Map<String, dynamic>.from(analysis as Map);

    setState(() {
      _tripAnalysis = analysisData;
      _isAnalyzing = false;
      _journeyReady = false;
      _analysisComplete = true;
    });

    _addAdvisoryToChat(analysisData);

    _addBotMessage(
      'Your journey analysis is ready. I am redirecting you to the report...',
    );

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        await Navigator.pushNamed(
          context,
          AppRoutes.journeyAnalysis,
          arguments: {
            'analysis': _tripAnalysis,
            'source': _source,
            'destination': _destination,
            'role': _role,
            'tripId': _tripId,
          },
        );

        if (mounted) {
          if (_role == 'traveler') {
            _startLiveUpdatesQuestionnaire();
          } else {
            _addBotMessage(
              'Your journey analysis has been loaded. Feel welcome to ask questions regarding conditions along your planned corridor.',
              quickReplies: const [
                'Why is this score low?',
                'Which segment needs attention?',
                'What precautions should I take?',
              ],
            );
          }
        }
      }
    });
  } on ApiException catch (e) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isAnalyzing = false;
    });

    _addBotMessage(
      'I couldn’t complete the journey analysis.',
    );

    _showError(e.message);
  } catch (_) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isAnalyzing = false;
    });

    _addBotMessage(
      'Something went wrong while analyzing your journey. Please try again.',
    );

    _showError(
      'Something went wrong while analyzing your journey.',
    );
  }
}

  // ============================================================
  // LIVE UPDATES / USER INPUT QUESTIONNAIRE
  // ============================================================

  void _startLiveUpdatesQuestionnaire() {
    _isCollectingLiveUpdates = true;
    _step = _ConversationStep.liveUpdateRain;
    _addBotMessage(
      'Share your live route observations to keep corridor intelligence updated. Are you experiencing rain along the route?',
      quickReplies: const [
        'None',
        'Light drizzle',
        'Moderate rain',
        'Heavy downpour',
        'Skip live updates',
      ],
    );
  }

  void _handleLiveUpdateMessage(String message) {
    final lower = message.toLowerCase().trim();

    if (lower.contains('skip')) {
      _finishLiveUpdates(skipped: true);
      return;
    }

    switch (_step) {
      case _ConversationStep.liveUpdateRain:
        _rain = message.trim();
        _step = _ConversationStep.liveUpdateVisibility;
        _addBotMessage(
          'How is visibility along your section?',
          quickReplies: const [
            'Clear (> 1 km)',
            'Moderate mist (500m - 1km)',
            'Dense fog (< 200m)',
            'Near zero visibility',
          ],
        );
        break;

      case _ConversationStep.liveUpdateVisibility:
        _visibility = message.trim();
        _step = _ConversationStep.liveUpdateHazards;
        _addBotMessage(
          'What is the road condition along your section?',
          quickReplies: const [
            'Smooth / Dry',
            'Wet / Slippery',
            'Waterlogging',
            'Potholes',
            'Landslide / Rockfall',
            'Debris',
          ],
        );
        break;

      case _ConversationStep.liveUpdateHazards:
        _unusualConditions = message.trim();
        _step = _ConversationStep.liveUpdateTraffic;
        _addBotMessage(
          'How is traffic moving along your section?',
          quickReplies: const [
            'Free flow',
            'Moderate delay',
            'Heavy congestion',
            'Standstill',
          ],
        );
        break;

      case _ConversationStep.liveUpdateTraffic:
        _traffic = message.trim();
        _finishLiveUpdates(skipped: false);
        break;

      default:
        _finishLiveUpdates(skipped: true);
        break;
    }
  }

  Future<void> _finishLiveUpdates({required bool skipped}) async {
    _isCollectingLiveUpdates = false;
    _step = _ConversationStep.postAnalysis;

    if (skipped) {
      _addBotMessage(
        'Live observations skipped. Feel welcome to ask questions regarding your corridor.',
        quickReplies: const [
          'Why is this score low?',
          'Which segment needs attention?',
          'What precautions should I take?',
        ],
      );
      return;
    }

    if (_tripId != null) {
      try {
        await ApiService.submitObservation(
          tripId: _tripId!,
          rain: _rain,
          visibility: _visibility,
          traffic: _traffic,
          unusualConditions: _unusualConditions,
          rawMessage: 'Rain: $_rain; Visibility: $_visibility; Road: $_unusualConditions; Traffic: $_traffic',
        );
      } catch (_) {}
    }

    _addBotMessage(
      'Thank you! Your road condition observation has been recorded successfully.',
    );
    _addBotMessage(
      'Feel welcome to ask questions regarding your corridor assessment.',
      quickReplies: const [
        'Why is this score low?',
        'Which segment needs attention?',
        'What precautions should I take?',
      ],
    );
  }

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

  static String _resolveSegmentName(String raw) {
    if (raw.trim().isEmpty) return '';
    final trimmed = raw.trim().toUpperCase();
    if (_corridorSegmentMap.containsKey(trimmed)) {
      return _corridorSegmentMap[trimmed]!;
    }
    String text = raw;
    _corridorSegmentMap.forEach((code, name) {
      text = text.replaceAll(RegExp('\\b$code\\b', caseSensitive: false), name);
    });
    return text;
  }

  // ============================================================
  // ADVISORY IN CHAT
  // ============================================================

  void _addAdvisoryToChat(
    dynamic analysis,
  ) {
    if (analysis == null) {
      _addBotMessage(
        'The analysis service did not provide a journey result.',
      );
      return;
    }

    final double? safetyScore =
        _readDouble(
      analysis,
      'overallSafetyScore',
    );

    final bool isPlanner = _role == 'planner';
    final double score = safetyScore ?? 80;
    final String verdict = score >= 80
        ? 'Safe to travel'
        : score >= 60
            ? 'Moderate caution recommended'
            : 'Caution advised along certain stretches';

    final String titlePrefix =
        isPlanner ? 'Planned Journey Safety Score' : 'Journey Safety Score';
    _addBotMessage(
      '$titlePrefix: ${_formatNumber(score)}/100 ($verdict)',
    );

    final dynamic segments = _readProperty(analysis, 'problematicSegments');
    if (segments is List && segments.isNotEmpty) {
      final List<String> flaggedNames = [];
      for (final dynamic seg in segments.take(2)) {
        final String rawReg = _readDynamicString(seg, 'region');
        final String reg = _resolveSegmentName(rawReg);
        if (reg.isNotEmpty && !flaggedNames.contains(reg)) {
          flaggedNames.add(reg);
        }
      }
      if (flaggedNames.isNotEmpty) {
        _addBotMessage(
          'Keep watch near: ${flaggedNames.join(', ')}.',
        );
      }
    } else {
      _addBotMessage(
        'All route segments are clear with no major hazards reported.',
      );
    }

    final List<String> precautions = _generatePrecautions(analysis);
    if (precautions.isNotEmpty) {
      _addBotMessage(
        'Quick tip: ${precautions.first}',
      );
    }

    _addBotMessage(
      'Feel welcome to ask me questions regarding conditions along your corridor.',
    );
  }



  // ============================================================
  // PRECAUTIONS GENERATION
  // ============================================================

  List<String>
      _generatePrecautions(
    dynamic analysis,
  ) {
    final List<String>
        precautions = [];

    final List<String>
        reasons =
        _stringList(
      _readProperty(
        analysis,
        'reasons',
      ),
    );

    final String joined =
        reasons.join(
      ' ',
    ).toLowerCase();

    if (joined.contains(
          'landslide',
        ) ||
        joined.contains(
          'rockfall',
        )) {
      precautions.add(
        'Stay alert near ghat sections and avoid stopping near unstable slopes.',
      );
    }

    if (joined.contains(
          'slippery',
        )) {
      precautions.add(
        'Reduce speed and maintain extra following distance on wet or slippery road sections.',
      );
    }

    if (joined.contains(
          'flood',
        ) ||
        joined.contains(
          'waterlogging',
        )) {
      precautions.add(
        'Avoid entering waterlogged sections when the road condition or depth cannot be assessed safely.',
      );
    }

    if (joined.contains(
          'visibility',
        ) ||
        joined.contains(
          'fog',
        )) {
      precautions.add(
        'Use appropriate lighting and reduce speed when visibility is reduced.',
      );
    }

    if (joined.contains(
          'heavy rain',
        ) ||
        joined.contains(
          'very heavy rain',
        )) {
      precautions.add(
        'Allow additional travel time and avoid sudden braking or acceleration on wet surfaces.',
      );
    }

    if (precautions.isEmpty) {
      precautions.add(
        'Follow current road conditions, maintain a safe speed, and reassess conditions if they change during the journey.',
      );
    }

    return precautions;
  }



  // ============================================================
  // POST-ANALYSIS CHAT
  // ============================================================

// ============================================================
// POST-ANALYSIS CHAT
// ============================================================

Future<void> _handlePostAnalysisMessage(
  String message,
) async {
  final int? tripId = _tripId;

  if (tripId == null) {
    _addBotMessage(
      'I don’t have a valid trip ID for this journey. Please analyze the journey again.',
    );
    return;
  }

  final String userMessage = message.trim();

  if (userMessage.isEmpty) {
    return;
  }

  setState(() {
    _isTyping = true;
  });

  _scrollToBottom();

  try {
    final Map<String, dynamic> response =
        await ApiService.sendChatbotMessage(
      tripId: tripId,
      message: userMessage,
    );

    if (!mounted) {
      return;
    }

    final String answer =
        response['answer']?.toString().trim() ?? '';

    setState(() {
      _isTyping = false;
    });

    if (answer.isEmpty) {
      _addBotMessage(
        'I received the request, but the travel assistant did not return an answer. Please try asking again.',
      );
      return;
    }

    _addBotMessage(answer);
  } on ApiException catch (e) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isTyping = false;
    });

    _addBotMessage(
      'I could not retrieve a response from the travel assistant at this moment.',
    );

    _showError(e.message);
  } catch (_) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isTyping = false;
    });

    _addBotMessage(
      'Something went wrong while contacting the travel assistant. Please try again.',
    );

    _showError(
      'Unable to contact the chatbot service.',
    );
  }
}

  // ============================================================
  // ROUTE RESOLUTION
  // ============================================================

  _RoutePoint
      _getNearestRoutePoint(
    double latitude,
    double longitude,
  ) {
    _RoutePoint nearest =
        _routePoints.first;

    double smallestDistance =
        _calculateDistance(
      latitude,
      longitude,
      nearest.latitude,
      nearest.longitude,
    );

    for (final point
        in _routePoints.skip(1)) {
      final double distance =
          _calculateDistance(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );

      if (distance <
          smallestDistance) {
        smallestDistance =
            distance;
        nearest =
            point;
      }
    }

    return nearest;
  }

  _RoutePoint? _findRoutePoint(
    String input,
  ) {
    final String normalized =
        _normalizeLocationText(
      input,
    );

    for (final point
        in _routePoints) {
      final String name =
          point.name.toLowerCase();

      final String display =
          point.displayName
              .toLowerCase();

      if (normalized == name ||
          normalized == display ||
          normalized.contains(
            name,
          ) ||
          name.contains(
            normalized,
          )) {
        return point;
      }
    }

    if (normalized.contains(
          'mumbai',
        ) ||
        normalized.contains(
          'mumbi',
        ) ||
        normalized.contains(
          'sion',
        )) {
      return _routePoints[0];
    }

    if (normalized.contains(
      'panvel',
    )) {
      return _routePoints[1];
    }

    if (normalized.contains(
      'khalapur',
    )) {
      return _routePoints[2];
    }

    if (normalized.contains(
      'khopoli',
    )) {
      return _routePoints[3];
    }

    if (normalized.contains(
      'khandala',
    )) {
      return _routePoints[4];
    }

    if (normalized.contains(
      'lonavala',
    )) {
      return _routePoints[5];
    }

    if (normalized.contains(
      'kamshet',
    )) {
      return _routePoints[6];
    }

    if (normalized.contains(
      'pune',
    )) {
      return _routePoints[7];
    }

    return null;
  }

  String _normalizeLocationText(
    String value,
  ) {
    return value
        .toLowerCase()
        .replaceAll(
          '/',
          ' ',
        )
        .replaceAll(
          '-',
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius =
        6371;

    final double dLat =
        (lat2 - lat1) *
            math.pi /
            180;

    final double dLon =
        (lon2 - lon1) *
            math.pi /
            180;

    final double lat1Rad =
        lat1 *
            math.pi /
            180;

    final double lat2Rad =
        lat2 *
            math.pi /
            180;

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

  // ============================================================
  // DATE
  // ============================================================

  String? _parsePlannerDate(
    String input,
  ) {
    final String normalized =
        input.toLowerCase().trim();

    final DateTime now =
        DateTime.now();

    if (normalized == 'today' ||
        normalized == 'same day') {
      return _formatDate(
        now,
      );
    }

    if (normalized ==
        'tomorrow') {
      return _formatDate(
        now.add(
          const Duration(
            days: 1,
          ),
        ),
      );
    }

    final RegExp pattern =
        RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$',
    );

    final Match? match =
        pattern.firstMatch(
      normalized,
    );

    if (match == null) {
      return null;
    }

    final int? day =
        int.tryParse(
      match.group(1)!,
    );

    final int? month =
        int.tryParse(
      match.group(2)!,
    );

    final int? year =
        int.tryParse(
      match.group(3)!,
    );

    if (day == null ||
        month == null ||
        year == null) {
      return null;
    }

    try {
      final DateTime date =
          DateTime(
        year,
        month,
        day,
      );

      if (date.year != year ||
          date.month != month ||
          date.day != day) {
        return null;
      }

      return _formatDate(
        date,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TIME
  // ============================================================

  String? _parsePlannerTime(
    String input,
  ) {
    final String normalized =
        input.toLowerCase().trim();

    if (normalized ==
        'morning') {
      return '09:00:00';
    }

    if (normalized ==
        'afternoon') {
      return '14:00:00';
    }

    if (normalized ==
        'evening') {
      return '18:00:00';
    }

    if (normalized ==
        'night') {
      return '21:00:00';
    }

    final RegExp pattern =
        RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(am|pm))?$',
    );

    final Match? match =
        pattern.firstMatch(
      normalized,
    );

    if (match == null) {
      return null;
    }

    int? hour =
        int.tryParse(
      match.group(1)!,
    );

    final int? minute =
        int.tryParse(
      match.group(2)!,
    );

    final String? period =
        match.group(3);

    if (hour == null ||
        minute == null ||
        minute > 59) {
      return null;
    }

    if (period != null) {
      if (hour < 1 ||
          hour > 12) {
        return null;
      }

      if (period == 'pm' &&
          hour != 12) {
        hour += 12;
      }

      if (period == 'am' &&
          hour == 12) {
        hour = 0;
      }
    }

    if (hour < 0 ||
        hour > 23) {
      return null;
    }

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }

  // ============================================================
  // TRAVELER NORMALIZATION
  // ============================================================

  String _normalizeUnusualCondition(
    String value,
  ) {
    final String normalized =
        value.toLowerCase().trim();

    if (normalized.contains(
          'nothing',
        ) ||
        normalized == 'none') {
      return 'None';
    }

    if (normalized.contains(
      'slippery',
    )) {
      return 'Slippery road';
    }

    if (normalized.contains(
          'waterlogging',
        ) ||
        normalized.contains(
          'flood',
        )) {
      return 'Flooding';
    }

    if (normalized.contains(
          'landslide',
        ) ||
        normalized.contains(
          'rockfall',
        ) ||
        normalized.contains(
          'rock fall',
        )) {
      return 'Landslide/Rockfall';
    }

    if (normalized.contains(
      'fallen tree',
    )) {
      return 'Fallen Tree';
    }

    if (normalized.contains(
      'debris',
    )) {
      return 'Debris on Road';
    }

    if (normalized.contains(
          'road damage',
        ) ||
        normalized.contains(
          'damaged road',
        )) {
      return 'Road Damage';
    }

    if (normalized.contains(
          'construction',
        ) ||
        normalized.contains(
          'road work',
        )) {
      return 'Construction Activity';
    }

    if (normalized.contains(
          'accident',
        ) ||
        normalized.contains(
          'incident',
        )) {
      return 'Accident/Incident';
    }

    if (normalized.contains(
          'closure',
        ) ||
        normalized.contains(
          'closed',
        )) {
      return 'Road Closure';
    }

    return value.trim();
  }

  String _normalizeTraffic(
    String value,
  ) {
    final String normalized =
        value.toLowerCase().trim();

    if (normalized.contains(
      'free',
    )) {
      return 'Free Flow';
    }

    if (normalized ==
        'light') {
      return 'Light';
    }

    if (normalized.contains(
      'moderate',
    )) {
      return 'Moderate';
    }

    if (normalized.contains(
      'very heavy',
    )) {
      return 'Very Heavy';
    }

    if (normalized.contains(
      'heavy',
    )) {
      return 'Heavy';
    }

    if (normalized.contains(
      'standstill',
    )) {
      return 'Standstill';
    }

    return value.trim();
  }

  // ============================================================
  // ANALYSIS PROPERTY HELPERS
  // ============================================================

  dynamic _readProperty(
    dynamic object,
    String property,
  ) {
    if (object == null) {
      return null;
    }

    // ----------------------------------------------------------
    // API response is a Map<String, dynamic>.
    // Support both backend snake_case and UI camelCase names.
    // ----------------------------------------------------------
    if (object is Map) {
      switch (property) {
        case 'overallSafetyScore':
          return object['overallSafetyScore'] ??
              object['overall_safety_score'];

        case 'overallConfidence':
          return object['overallConfidence'] ??
              object['overall_confidence'];

        case 'status':
          return object['status'];

        case 'problematicSegments':
          return object['problematicSegments'] ??
              object['problematic_segments'];

        case 'reasons':
          return object['reasons'];

        case 'availableIntelligenceSources':
          return object['availableIntelligenceSources'] ??
              object['available_intelligence_sources'];

        case 'missingIntelligenceSources':
          return object['missingIntelligenceSources'] ??
              object['missing_intelligence_sources'];

        case 'segmentDetails':
          return object['segmentDetails'] ??
              object['segment_details'];

        case 'region':
          return object['region'];

        case 'safetyScore':
          return object['safetyScore'] ??
              object['safety_score'];

        case 'confidence':
          return object['confidence'];

        case 'start':
          return object['start'];

        case 'end':
          return object['end'];

        default:
          return object[property];
      }
    }

    // ----------------------------------------------------------
    // Backward compatibility if an older Dart model is ever
    // passed instead of a Map.
    // ----------------------------------------------------------
    try {
      switch (property) {
        case 'overallSafetyScore':
          return object.overallSafetyScore;

        case 'overallConfidence':
          return object.overallConfidence;

        case 'status':
          return object.status;

        case 'problematicSegments':
          return object.problematicSegments;

        case 'reasons':
          return object.reasons;

        case 'availableIntelligenceSources':
          return object.availableIntelligenceSources;

        case 'missingIntelligenceSources':
          return object.missingIntelligenceSources;

        case 'segmentDetails':
          return object.segmentDetails;

        case 'region':
          return object.region;

        case 'safetyScore':
          return object.safetyScore;

        case 'confidence':
          return object.confidence;

        case 'start':
          return object.start;

        case 'end':
          return object.end;

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  double? _readDouble(
    dynamic object,
    String property,
  ) {
    final dynamic value = _readProperty(
      object,
      property,
    );

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }



  String _readDynamicString(
    dynamic object,
    String property,
  ) {
    final dynamic value = _readProperty(
      object,
      property,
    );

    return value?.toString() ?? '';
  }


List<String> _stringList(
  dynamic value,
) {
  if (value is! List) {
    return [];
  }

  return value
      .map(
        (item) => item.toString(),
      )
      .toList();
}

  String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(1);
  }

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
  // BACK BUTTON
  // ============================================================

  Future<bool>
      _handleBackNavigation() async {
    if (_isAnalyzing) {
      return false;
    }

    if (_analysisComplete) {
      final bool? leave =
          await showDialog<bool>(
        context: context,
        builder:
            (context) {
          return AlertDialog(
            title: const Text(
              'Leave journey analysis?',
            ),
            content:
                const Text(
              'Your completed analysis will remain stored with this trip, but the current chat conversation will close.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                  false,
                ),
                child:
                    const Text(
                  'STAY',
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                  true,
                ),
                child:
                    const Text(
                  'LEAVE',
                ),
              ),
            ],
          );
        },
      );

      return leave ?? false;
    }

    return true;
  }

  // ============================================================
  // MESSAGE HELPERS
  // ============================================================

  void _addBotMessage(
    String message, {
    List<String>
        quickReplies =
        const [],
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          text: message,
          isUser: false,
          quickReplies:
              quickReplies,
        ),
      );
    });

    _scrollToBottom();
  }

  void _addUserMessage(
    String message,
  ) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: message,
          isUser: true,
        ),
      );
    });

    _scrollToBottom();
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildMessageInput() {
    final bool disabled =
        _isTyping ||
            _isAnalyzing;

    String hintText = _analysisComplete
        ? 'Ask about your journey...'
        : 'Type your answer...';

    if (_step == _ConversationStep.plannerDate) {
      hintText = 'Tap calendar icon or type date...';
    } else if (_step == _ConversationStep.plannerTime) {
      hintText = 'Tap clock icon or pick departure time...';
    }

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),
      decoration:
          BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:
                  _messageController,
              enabled:
                  !disabled,
              textInputAction:
                  TextInputAction
                      .send,
              onSubmitted:
                  (_) =>
                      _sendMessage(),
              onTap: () {
                if (_step == _ConversationStep.plannerDate) {
                  _pickPlannerDate();
                } else if (_step == _ConversationStep.plannerTime) {
                  _pickPlannerTime();
                }
              },
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.darkNavy,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: AppTheme.forestGreen,
              decoration:
                  InputDecoration(
                prefixIcon: (_step == _ConversationStep.plannerDate)
                    ? IconButton(
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.forestGreen,
                          size: 24,
                        ),
                        tooltip: 'Select Date on Calendar',
                        onPressed: disabled ? null : _pickPlannerDate,
                      )
                    : (_step == _ConversationStep.plannerTime)
                        ? IconButton(
                            icon: const Icon(
                              Icons.access_time_filled_rounded,
                              color: AppTheme.forestGreen,
                              size: 24,
                            ),
                            tooltip: 'Pick Time on Clock',
                            onPressed: disabled ? null : _pickPlannerTime,
                          )
                        : null,
                hintText: hintText,
                filled: true,
                fillColor:
                    AppTheme.lightMint,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    16,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Material(
            color: disabled
                ? AppTheme.border
                : AppTheme.forestGreen,
            borderRadius:
                BorderRadius.circular(
              15,
            ),
            child: InkWell(
              onTap: disabled
                  ? null
                  : _sendMessage,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              child:
                  const SizedBox(
                width: 50,
                height: 50,
                child: Icon(
                  Icons
                      .send_rounded,
                  color:
                      AppTheme.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANALYZE BUTTON
  // ============================================================

  Widget _buildAnalyzeButton() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.white,
        border: Border(
          top: BorderSide(
            color:
                AppTheme.border,
          ),
        ),
      ),
      child: SizedBox(
        height: 54,
        child:
            ElevatedButton.icon(
          onPressed:
              _isAnalyzing
                  ? null
                  : _analyzeJourney,
          icon:
              _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .analytics_rounded,
                    ),
          label:
              Text(
            _isAnalyzing
                ? 'ANALYZING...'
                : 'ANALYZE JOURNEY',
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TYPING INDICATOR
  // ============================================================

  Widget _buildTypingIndicator() {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              AppTheme.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color:
                AppTheme.border,
          ),
        ),
        child:
            const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            _TypingDot(),
            SizedBox(
              width: 4,
            ),
            _TypingDot(),
            SizedBox(
              width: 4,
            ),
            _TypingDot(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE & FORMATTING
  // ============================================================

  Widget _buildFormattedMessageText(
    String text,
    bool isUser,
  ) {
    final TextStyle defaultStyle = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: isUser ? AppTheme.white : AppTheme.textPrimary,
    );

    final TextStyle boldStyle = defaultStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: isUser ? AppTheme.white : AppTheme.darkNavy,
    );

    // Replace markdown star bullets with bullet character
    final String cleaned = text.replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '• ');

    if (!cleaned.contains('**')) {
      return Text(
        cleaned,
        style: defaultStyle,
      );
    }

    final List<InlineSpan> spans = [];
    final RegExp regex = RegExp(r'\*\*(.+?)\*\*');
    int lastIndex = 0;

    for (final Match match in regex.allMatches(cleaned)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: cleaned.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: boldStyle,
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < cleaned.length) {
      spans.add(
        TextSpan(
          text: cleaned.substring(lastIndex),
          style: defaultStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildMessageBubble(
    _ChatMessage message,
  ) {
    return Column(
      crossAxisAlignment:
          message.isUser
              ? CrossAxisAlignment
                  .end
              : CrossAxisAlignment
                  .start,
      children: [
        Align(
          alignment:
              message.isUser
                  ? Alignment
                      .centerRight
                  : Alignment
                      .centerLeft,
          child:
              Container(
            constraints:
                const BoxConstraints(
              maxWidth: 330,
            ),
            margin:
                const EdgeInsets
                    .only(
              bottom: 8,
            ),
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            decoration:
                BoxDecoration(
              color: message
                      .isUser
                  ? AppTheme
                      .forestGreen
                  : AppTheme.white,
              borderRadius:
                  BorderRadius.only(
                topLeft:
                    const Radius
                        .circular(
                  18,
                ),
                topRight:
                    const Radius
                        .circular(
                  18,
                ),
                bottomLeft:
                    Radius.circular(
                  message.isUser
                      ? 18
                      : 5,
                ),
                bottomRight:
                    Radius.circular(
                  message.isUser
                      ? 5
                      : 18,
                ),
              ),
              border:
                  message.isUser
                      ? null
                      : Border.all(
                          color:
                              AppTheme
                                  .border,
                        ),
            ),
            child: _buildFormattedMessageText(
              message.text,
              message.isUser,
            ),
          ),
        ),
        if (!message.isUser &&
            message.quickReplies
                .isNotEmpty)
          _buildQuickReplies(
            message
                .quickReplies,
          ),
      ],
    );
  }

  // ============================================================
  // QUICK REPLIES
  // ============================================================

  Widget _buildQuickReplies(
    List<String> replies,
  ) {
    return Padding(
      padding:
          const EdgeInsets
              .only(
        bottom: 12,
      ),
      child:
          Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            replies.map(
          (reply) {
            return OutlinedButton(
              onPressed:
                  () =>
                      _selectQuickReply(
                reply,
              ),
              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    AppTheme
                        .forestGreen,
                side:
                    BorderSide(
                  color:
                      AppTheme
                          .forestGreen,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      14,
                  vertical:
                      9,
                ),
              ),
              child:
                  Text(
                reply,
                style:
                    const TextStyle(
                  fontSize:
                      12.5,
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
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

 return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) {
      return;
    }

    final shouldLeave = await _handleBackNavigation();

    if (shouldLeave && context.mounted) {
      Navigator.of(context).pop(result);
    }
  },
 
  child: Scaffold(
        
      backgroundColor:
          AppTheme.lightMint,
      appBar:
          AppBar(
        backgroundColor:
            AppTheme.lightMint,
        elevation: 0,
        automaticallyImplyLeading:
            false,
        titleSpacing: 8,
        leading:
            IconButton(
          onPressed:
              _isAnalyzing
                  ? null
                  : () async {
                      final bool
                          shouldLeave =
                          await _handleBackNavigation();

                      if (shouldLeave &&
                          context.mounted) {
                        Navigator.pop(
                          context,
                        );
                      }
                    },
          icon:
              const Icon(
            Icons
                .arrow_back_rounded,
            color:
                AppTheme.darkNavy,
          ),
        ),
        title:
            Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    AppTheme
                        .forestGreen,
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .auto_awesome_rounded,
                color:
                    AppTheme.white,
                size:
                    22,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Travel Advisor',
                    style:
                        TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight
                              .w800,
                      color:
                          AppTheme
                              .darkNavy,
                    ),
                  ),
                  Text(
                    isPlanner
                        ? 'Journey Planner'
                        : 'Traveler',
                    style:
                        const TextStyle(
                      fontSize:
                          12,
                      color:
                          AppTheme
                              .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      body:
          SafeArea(
        top: false,
        child:
            Column(
          children: [
            Expanded(
              child:
                  ListView
                      .builder(
                controller:
                    _scrollController,
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  12,
                  16,
                  20,
                ),
                itemCount:
                    _messages.length +
                        (_isTyping
                            ? 1
                            : 0),
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  if (_isTyping &&
                      index ==
                          _messages
                              .length) {
                    return _buildTypingIndicator();
                  }

                  return _buildMessageBubble(
                    _messages[
                        index],
                  );
                },
              ),
            ),
            if (_journeyReady &&
                !_analysisComplete)
              _buildAnalyzeButton(),
            if (!_journeyReady ||
                _analysisComplete)
              _buildMessageInput(),
          ],
        ),
      ),
    ),
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }
}

// ============================================================
// ROUTE POINT
// ============================================================

class _RoutePoint {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;

  const _RoutePoint({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

// ============================================================
// CONVERSATION STEP
// ============================================================

enum _ConversationStep {
  confirmSource,
  manualSource,
  destination,
  plannerDate,
  plannerTime,
  travelerRain,
  travelerVisibility,
  travelerFog,
  travelerUnusual,
  travelerTraffic,
  ready,
  liveUpdateRain,
  liveUpdateVisibility,
  liveUpdateHazards,
  liveUpdateTraffic,
  postAnalysis,
}

// ============================================================
// CHAT MESSAGE
// ============================================================

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> quickReplies;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.quickReplies =
        const [],
  });
}

// ============================================================
// TYPING DOT
// ============================================================

class _TypingDot
    extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 6,
      height: 6,
      decoration:
          const BoxDecoration(
        color:
            AppTheme.textSecondary,
        shape:
            BoxShape.circle,
      ),
    );
  }
}


