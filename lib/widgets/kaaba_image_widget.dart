import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Kaaba Image Widget for Qibla Compass
/// Displays a Kaaba image that rotates to point towards Qibla
class KaabaImageWidget extends StatelessWidget {
  final double rotationAngle; // Angle in radians
  final double size;

  const KaabaImageWidget({
    super.key,
    required this.rotationAngle,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: rotationAngle / (2 * math.pi),
      duration: const Duration(milliseconds: 300),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Kaaba Image from assets
          Image.asset(
            'assets/images/khanakhaba.jpg',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to custom drawn Kaaba if image not found
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B4513), // Brown base
                      const Color(0xFF654321), // Darker brown
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: Size(size, size),
                  painter: KaabaPainter(),
                ),
              );
            },
          ),
          // Green line pointing to Qibla direction
          CustomPaint(
            size: Size(size * 2, size * 2),
            painter: QiblaLinePainter(
              qiblaAngle: rotationAngle,
              lineLength: size * 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for Kaaba structure
class KaabaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32) // Green color for Kiswah (replaced gold)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width * 0.6;
    final height = size.height * 0.7;

    // Draw Kaaba structure (simplified cube representation)
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      ),
      const Radius.circular(4),
    );

    // Draw main structure
    canvas.drawRRect(rect, paint);

    // Draw Kiswah (black cloth) pattern
    final kiswahPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Horizontal lines (Kiswah bands)
    for (int i = 1; i < 3; i++) {
      final y = center.dy - height / 2 + (height * i / 3);
      canvas.drawLine(
        Offset(center.dx - width / 2, y),
        Offset(center.dx + width / 2, y),
        kiswahPaint,
      );
    }

    // Vertical decorative lines
    for (int i = 1; i < 2; i++) {
      final x = center.dx - width / 2 + (width * i / 2);
      canvas.drawLine(
        Offset(x, center.dy - height / 2),
        Offset(x, center.dy + height / 2),
        kiswahPaint,
      );
    }

    // Draw door (simplified)
    final doorPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    final doorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + height * 0.1),
        width: width * 0.3,
        height: height * 0.4,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(doorRect, doorPaint);

    // Draw door frame
    final doorFramePaint = Paint()
      ..color = const Color(0xFF2E7D32) // Green instead of gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(doorRect, doorFramePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for green Qibla direction line
/// Draws a line pointing upward (0 radians) since the widget rotates to face Qibla
class QiblaLinePainter extends CustomPainter {
  final double qiblaAngle; // Angle in radians (for repaint detection)
  final double lineLength;

  QiblaLinePainter({
    required this.qiblaAngle,
    required this.lineLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Line points upward (0 radians = pointing up/north)
    // The entire widget will be rotated to face Qibla direction
    final endPoint = Offset(center.dx, center.dy - lineLength);

    // Draw green line with shadow for visibility
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(center, endPoint, shadowPaint);

    // Draw main green line
    final linePaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, endPoint, linePaint);

    // Draw arrowhead at the end pointing to Qibla
    final arrowPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.fill;

    final arrowSize = 14.0;
    final arrowAngle = -math.pi / 2; // Pointing upward (0 degrees = up)
    
    final arrowPath = Path();
    final arrowPoint1 = Offset(
      endPoint.dx - arrowSize * math.cos(arrowAngle - math.pi / 6),
      endPoint.dy - arrowSize * math.sin(arrowAngle - math.pi / 6),
    );
    final arrowPoint2 = Offset(
      endPoint.dx - arrowSize * math.cos(arrowAngle + math.pi / 6),
      endPoint.dy - arrowSize * math.sin(arrowAngle + math.pi / 6),
    );
    
    arrowPath.moveTo(endPoint.dx, endPoint.dy);
    arrowPath.lineTo(arrowPoint1.dx, arrowPoint1.dy);
    arrowPath.lineTo(arrowPoint2.dx, arrowPoint2.dy);
    arrowPath.close();
    
    canvas.drawPath(arrowPath, arrowPaint);

    // Draw a small green circle at the center (Kaaba position indicator)
    final centerPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 6.0, centerPaint);
    
    // Draw outer ring for better visibility
    final ringPaint = Paint()
      ..color = Colors.green.shade700.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 10.0, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is QiblaLinePainter) {
      return oldDelegate.qiblaAngle != qiblaAngle || 
             oldDelegate.lineLength != lineLength;
    }
    return true;
  }
}

