import 'package:flutter/material.dart';
import '../../app/routes.dart';

/// Floating SOS button that opens the comprehensive Expressway Emergency & SOS screen.
class ExpresswaySosFloatingButton extends StatelessWidget {
  final String heroTag;

  const ExpresswaySosFloatingButton({
    super.key,
    this.heroTag = 'welcome_sos_fab',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => Navigator.pushNamed(context, AppRoutes.emergencySos),
      backgroundColor: const Color(0xFFDC2626), // Emergency red
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
      label: const Text(
        'SOS',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// AppBar SOS Icon Button that opens the Expressway Emergency Directory screen.
class ExpresswaySosIconButton extends StatelessWidget {
  const ExpresswaySosIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Expressway Emergency SOS',
      icon: const Icon(
        Icons.emergency_outlined,
        color: Color(0xFFDC2626),
      ),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.emergencySos),
    );
  }
}

/// Opens the Expressway Emergency & SOS Directory screen.
void showExpresswayEmergencySheet(BuildContext context, [dynamic emergencyDir]) {
  Navigator.pushNamed(context, AppRoutes.emergencySos);
}
