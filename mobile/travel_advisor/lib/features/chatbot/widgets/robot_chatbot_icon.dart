import 'package:flutter/material.dart';

/// A custom-painted vector robot / chatbot icon that does not depend on
/// external icon font glyphs or assets. This guarantees crisp rendering
/// across all release builds, OTA patches, and platforms without font tree-shaking issues.
class RobotChatbotIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RobotChatbotIcon({
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
        painter: _RobotChatbotPainter(color: color),
      ),
    );
  }
}

class _RobotChatbotPainter extends CustomPainter {
  final Color color;

  const _RobotChatbotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Head base (rounded rectangle)
    final RRect headRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.28, w * 0.64, h * 0.52),
      Radius.circular(w * 0.14),
    );

    // Antenna stalk and ball
    final Path antennaStalk = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.47, h * 0.14, w * 0.06, h * 0.15),
          Radius.circular(w * 0.03),
        ),
      );
    final Path antennaBall = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(w * 0.50, h * 0.12),
          radius: w * 0.06,
        ),
      );

    // Left and right ears
    final Path leftEar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.10, h * 0.44, w * 0.08, h * 0.20),
          Radius.circular(w * 0.04),
        ),
      );
    final Path rightEar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.82, h * 0.44, w * 0.08, h * 0.20),
          Radius.circular(w * 0.04),
        ),
      );

    // Outer silhouette = head + antenna + ears
    Path outer = Path()..addRRect(headRRect);
    outer = Path.combine(PathOperation.union, outer, antennaStalk);
    outer = Path.combine(PathOperation.union, outer, antennaBall);
    outer = Path.combine(PathOperation.union, outer, leftEar);
    outer = Path.combine(PathOperation.union, outer, rightEar);

    // Eyes (two circular cutouts)
    final Path leftEye = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(w * 0.36, h * 0.49),
          radius: w * 0.065,
        ),
      );
    final Path rightEye = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(w * 0.64, h * 0.49),
          radius: w * 0.065,
        ),
      );

    // Smile / friendly mouth cutout
    final Path smile = Path()
      ..moveTo(w * 0.38, h * 0.64)
      ..quadraticBezierTo(w * 0.50, h * 0.72, w * 0.62, h * 0.64)
      ..quadraticBezierTo(w * 0.50, h * 0.77, w * 0.38, h * 0.64)
      ..close();

    Path cutouts = Path.combine(PathOperation.union, leftEye, rightEye);
    cutouts = Path.combine(PathOperation.union, cutouts, smile);

    // Final silhouette with see-through eyes and smile
    final Path finalShape = Path.combine(PathOperation.difference, outer, cutouts);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(finalShape, paint);
  }

  @override
  bool shouldRepaint(covariant _RobotChatbotPainter oldDelegate) =>
      oldDelegate.color != color;
}
