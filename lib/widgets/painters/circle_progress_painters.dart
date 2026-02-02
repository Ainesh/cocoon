/// Custom painters for circular progress indicators.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dotted circle progress painter for health score visualization.
class DottedCircleProgressPainter extends CustomPainter {
  const DottedCircleProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.dotCount = 32,
    this.dotRadius = 3.2,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int dotCount;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - dotRadius - 4;
    final activeDots = (dotCount * progress).round();

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi / dotCount) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final paint = Paint()
        ..color = i < activeDots ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DottedCircleProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor;
  }
}

/// Continuous arc progress painter for small metric indicators.
class ContinuousCircleProgressPainter extends CustomPainter {
  const ContinuousCircleProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.strokeWidth = 3.0,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth - 2;

    // Draw inactive background circle
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw active progress arc
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ContinuousCircleProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor;
  }
}
