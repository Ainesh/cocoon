/// Custom painter for trend line charts.
///
/// Draws smooth curved lines with gradient fills, suitable for
/// visualizing score trends over time.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Paints a dual-line trend chart with smooth curves and gradient fills.
///
/// Used for visualizing connection and intimacy trends over time.
/// Each line has its own color and gradient fill under the curve.
class TrendChartPainter extends CustomPainter {
  const TrendChartPainter({
    required this.primaryValues,
    required this.secondaryValues,
    this.primaryColor,
    this.secondaryColor,
    this.maxValue = 10.0,
    this.strokeWidth = 2.5,
  });

  /// Primary line values (e.g., connection scores)
  final List<double> primaryValues;
  
  /// Secondary line values (e.g., intimacy scores)
  final List<double> secondaryValues;
  
  /// Primary line color (default: accentRed)
  final Color? primaryColor;
  
  /// Secondary line color (default: blue)
  final Color? secondaryColor;
  
  /// Maximum value for scaling (default: 10)
  final double maxValue;
  
  /// Line stroke width (default: 2.5)
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (primaryValues.isEmpty) return;
    
    final primary = primaryColor ?? AppColors.accentRed;
    final secondary = secondaryColor ?? const Color(0xFF60A5FA);
    
    // Draw primary line (red)
    _drawCurveLine(canvas, size, primaryValues, primary);
    
    // Draw secondary line (blue)
    _drawCurveLine(canvas, size, secondaryValues, secondary);
  }

  void _drawCurveLine(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
  ) {
    if (values.isEmpty) return;

    final count = values.length;
    final points = <Offset>[];
    
    for (int i = 0; i < count; i++) {
      final x = count == 1 ? size.width / 2 : (i / (count - 1)) * size.width;
      final y = size.height - ((values[i] / maxValue) * size.height * 0.9);
      points.add(Offset(x, y));
    }

    if (points.length < 2) {
      // Just draw a dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, 4, dotPaint);
      return;
    }

    // Create smooth curve path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 4;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 4;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 4;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 4;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // Fill under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw dot at the last point
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return primaryValues != oldDelegate.primaryValues ||
        secondaryValues != oldDelegate.secondaryValues ||
        primaryColor != oldDelegate.primaryColor ||
        secondaryColor != oldDelegate.secondaryColor;
  }
}
