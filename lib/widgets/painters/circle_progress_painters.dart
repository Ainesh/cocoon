/// Custom painters for circular progress indicators.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dotted circle progress painter for health score visualisation.
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

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi / dotCount) * i - math.pi / 2;
      paint.color = i < activeDots ? activeColor : inactiveColor;
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle)),
        dotRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DottedCircleProgressPainter oldDelegate) =>
      progress != oldDelegate.progress ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor;
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

    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ContinuousCircleProgressPainter oldDelegate) =>
      progress != oldDelegate.progress ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor;
}
