import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 1. Live Radar Beacon Icon (Sensors / Live Updates)
class LiveRadarIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool showLivePulse;

  const LiveRadarIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.showLivePulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RadarPainter(color: color),
          ),
          if (showLivePulse)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  _RadarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.62);
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.085)
      ..strokeCap = StrokeCap.round;

    // Outer arc
    final outerRadius = size.width * 0.44;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      -math.pi * 0.82,
      math.pi * 0.64,
      false,
      strokePaint,
    );

    // Inner arc
    final innerRadius = size.width * 0.26;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -math.pi * 0.82,
      math.pi * 0.64,
      false,
      strokePaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.11, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.color != color;
}

/// 2. Corridor Route Hub Icon (Branching highway / Hub)
class CorridorHubIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CorridorHubIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CorridorHubPainter(color: color),
      ),
    );
  }
}

class _CorridorHubPainter extends CustomPainter {
  final Color color;
  _CorridorHubPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.width * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Stem path
    final path = Path();
    path.moveTo(w * 0.5, h * 0.84);
    path.lineTo(w * 0.5, h * 0.52);

    // Left branch
    final leftPath = Path();
    leftPath.moveTo(w * 0.5, h * 0.52);
    leftPath.quadraticBezierTo(w * 0.5, h * 0.35, w * 0.25, h * 0.26);

    // Right branch
    final rightPath = Path();
    rightPath.moveTo(w * 0.5, h * 0.52);
    rightPath.quadraticBezierTo(w * 0.5, h * 0.35, w * 0.75, h * 0.26);

    canvas.drawPath(path, strokePaint);
    canvas.drawPath(leftPath, strokePaint);
    canvas.drawPath(rightPath, strokePaint);

    // Junction nodes
    final nodeRadius = w * 0.095;
    canvas.drawCircle(Offset(w * 0.5, h * 0.84), nodeRadius, fillPaint);
    canvas.drawCircle(Offset(w * 0.25, h * 0.25), nodeRadius, fillPaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.25), nodeRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CorridorHubPainter oldDelegate) => oldDelegate.color != color;
}

/// 3. Commute Clock / Alarm Icon
class CommuteClockIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CommuteClockIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ClockPainter(color: color),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final Color color;
  _ClockPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.085)
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.54);
    final radius = w * 0.36;

    // Clock circle
    canvas.drawCircle(center, radius, strokePaint);

    // Clock hands
    final handsPath = Path();
    handsPath.moveTo(center.dx, center.dy);
    handsPath.lineTo(center.dx, center.dy - radius * 0.55);
    handsPath.moveTo(center.dx, center.dy);
    handsPath.lineTo(center.dx + radius * 0.45, center.dy);
    canvas.drawPath(handsPath, strokePaint);

    // Alarm bells on top
    canvas.drawLine(
      Offset(w * 0.22, h * 0.20),
      Offset(w * 0.32, h * 0.28),
      strokePaint,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.20),
      Offset(w * 0.68, h * 0.28),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) => oldDelegate.color != color;
}

/// 4. Saved Reports Bookmark Icon
class SavedReportsBookmarkIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SavedReportsBookmarkIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BookmarkPainter(color: color),
      ),
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  final Color color;
  _BookmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.26, h * 0.16);
    path.lineTo(w * 0.74, h * 0.16);
    path.lineTo(w * 0.74, h * 0.84);
    path.lineTo(w * 0.5, h * 0.64);
    path.lineTo(w * 0.26, h * 0.84);
    path.close();

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPainter oldDelegate) => oldDelegate.color != color;
}

/// 5. Hazard Category Custom Icons (Rain, Visibility, Road, Traffic)
class HazardCategoryIcon extends StatelessWidget {
  final String category; // 'visibility', 'rain', 'road', 'traffic'
  final double size;
  final Color color;

  const HazardCategoryIcon({
    super.key,
    required this.category,
    this.size = 15,
    this.color = const Color(0xFFF59E0B),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _HazardPainter(category: category.toLowerCase(), color: color),
      ),
    );
  }
}

class _HazardPainter extends CustomPainter {
  final String category;
  final Color color;
  _HazardPainter({required this.category, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, size.width * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    if (category.contains('rain')) {
      // Cloud + drops
      final cloudPath = Path();
      cloudPath.moveTo(w * 0.25, h * 0.50);
      cloudPath.quadraticBezierTo(w * 0.2, h * 0.32, w * 0.38, h * 0.32);
      cloudPath.quadraticBezierTo(w * 0.5, h * 0.18, w * 0.65, h * 0.32);
      cloudPath.quadraticBezierTo(w * 0.82, h * 0.32, w * 0.8, h * 0.50);
      cloudPath.close();
      canvas.drawPath(cloudPath, strokePaint);

      // Rain drops
      canvas.drawLine(Offset(w * 0.35, h * 0.62), Offset(w * 0.28, h * 0.78), strokePaint);
      canvas.drawLine(Offset(w * 0.55, h * 0.62), Offset(w * 0.48, h * 0.78), strokePaint);
      canvas.drawLine(Offset(w * 0.75, h * 0.62), Offset(w * 0.68, h * 0.78), strokePaint);
    } else if (category.contains('vis') || category.contains('fog')) {
      // Eye silhouette with pupil
      final eyePath = Path();
      eyePath.moveTo(w * 0.15, h * 0.5);
      eyePath.quadraticBezierTo(w * 0.5, h * 0.15, w * 0.85, h * 0.5);
      eyePath.quadraticBezierTo(w * 0.5, h * 0.85, w * 0.15, h * 0.5);
      canvas.drawPath(eyePath, strokePaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.14, fillPaint);
    } else if (category.contains('traffic') || category.contains('jam')) {
      // Vehicle silhouette
      final carPath = Path();
      carPath.moveTo(w * 0.2, h * 0.68);
      carPath.lineTo(w * 0.2, h * 0.52);
      carPath.lineTo(w * 0.32, h * 0.32);
      carPath.lineTo(w * 0.68, h * 0.32);
      carPath.lineTo(w * 0.8, h * 0.52);
      carPath.lineTo(w * 0.8, h * 0.68);
      carPath.close();
      canvas.drawPath(carPath, strokePaint);
      // Wheels
      canvas.drawCircle(Offset(w * 0.32, h * 0.74), w * 0.08, fillPaint);
      canvas.drawCircle(Offset(w * 0.68, h * 0.74), w * 0.08, fillPaint);
    } else {
      // Road hazard / Warning triangle
      final triPath = Path();
      triPath.moveTo(w * 0.5, h * 0.18);
      triPath.lineTo(w * 0.85, h * 0.82);
      triPath.lineTo(w * 0.15, h * 0.82);
      triPath.close();
      canvas.drawPath(triPath, strokePaint);
      // Exclamation point
      canvas.drawLine(Offset(w * 0.5, h * 0.42), Offset(w * 0.5, h * 0.60), strokePaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.06, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HazardPainter oldDelegate) =>
      oldDelegate.category != category || oldDelegate.color != color;
}

/// 6. Route Swap Arrow Icon (Bold directional arrows: Start Point ⇄ Destination)
class RouteSwapArrowIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RouteSwapArrowIcon({
    super.key,
    this.size = 20,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RouteSwapPainter(color: color),
      ),
    );
  }
}

class _RouteSwapPainter extends CustomPainter {
  final Color color;
  _RouteSwapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Top arrow pointing Right (→)
    final yTop = h * 0.36;
    canvas.drawLine(Offset(w * 0.12, yTop), Offset(w * 0.85, yTop), strokePaint);
    final topHead = Path();
    topHead.moveTo(w * 0.58, yTop - h * 0.20);
    topHead.lineTo(w * 0.88, yTop);
    topHead.lineTo(w * 0.58, yTop + h * 0.20);
    canvas.drawPath(topHead, strokePaint);

    // Bottom arrow pointing Left (←)
    final yBottom = h * 0.64;
    canvas.drawLine(Offset(w * 0.88, yBottom), Offset(w * 0.15, yBottom), strokePaint);
    final bottomHead = Path();
    bottomHead.moveTo(w * 0.42, yBottom - h * 0.20);
    bottomHead.lineTo(w * 0.12, yBottom);
    bottomHead.lineTo(w * 0.42, yBottom + h * 0.20);
    canvas.drawPath(bottomHead, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RouteSwapPainter oldDelegate) => oldDelegate.color != color;
}

