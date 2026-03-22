/// Personal trend card for solo mode dashboard.
///
/// Shows the user's own pulse check-in trend when they are the only
/// member of the space. Replaces the shared HealthCard mosaic.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_checkin.dart';
import '../../../theme/theme.dart';

/// Card displaying a personal check-in trend line for solo users.
///
/// Uses daily weighted-average scores from the user's recent check-ins
/// to paint a smooth curve with gradient fill.
class PersonalTrendCard extends StatelessWidget {
  const PersonalTrendCard({
    super.key,
    required this.checkIns,
    required this.streak,
    required this.onTap,
  });

  final List<UserCheckIn> checkIns;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.warmMuted.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR PULSE',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _buildChart(),
            const Spacer(),
            Text(
              'Invite your partner to see\nyour shared health score',
              style: GoogleFonts.inter(
                color: AppColors.warmMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final dailyScores = _computeDailyScores();
    if (dailyScores.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Check in to see your trend',
            style: GoogleFonts.inter(
              color: AppColors.warmDim,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: CustomPaint(
        size: const Size(double.infinity, 60),
        painter: _PersonalTrendPainter(values: dailyScores),
      ),
    );
  }

  /// Groups check-ins by calendar day and computes a weighted average
  /// overall score for each day, returning the last 14 days.
  List<double> _computeDailyScores() {
    if (checkIns.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final byDay = <int, List<double>>{};
    for (final ci in checkIns) {
      final day = DateTime(ci.timestamp.year, ci.timestamp.month,
          ci.timestamp.day);
      final daysAgo = today.difference(day).inDays;
      if (daysAgo > 13 || daysAgo < 0) continue;

      final weights = ci.configSnapshot.weights;
      double totalWeight = 0;
      double weightedSum = 0;
      for (final entry in ci.scores.entries) {
        final w = weights[entry.key] ?? 1.0;
        weightedSum += entry.value * w;
        totalWeight += w;
      }
      final overall = totalWeight > 0 ? weightedSum / totalWeight : 50.0;
      byDay.putIfAbsent(daysAgo, () => []).add(overall);
    }

    if (byDay.isEmpty) return [];

    final maxDay = byDay.keys.reduce(math.max);
    final result = <double>[];
    for (int d = maxDay; d >= 0; d--) {
      final scores = byDay[d];
      if (scores != null && scores.isNotEmpty) {
        result.add(scores.reduce((a, b) => a + b) / scores.length);
      }
    }
    return result;
  }
}

/// Painter for the personal trend curve.
class _PersonalTrendPainter extends CustomPainter {
  const _PersonalTrendPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / 100) * size.height * 0.85);
      points.add(Offset(x, y.clamp(2, size.height - 2)));
    }

    if (points.length < 2) {
      canvas.drawCircle(
        points.first,
        4,
        Paint()
          ..color = AppColors.accentRed
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final curvePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      curvePath.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 4,
        p1.dy + (p2.dy - p0.dy) / 4,
        p2.dx - (p3.dx - p1.dx) / 4,
        p2.dy - (p3.dy - p1.dy) / 4,
        p2.dx,
        p2.dy,
      );
    }

    // Gradient fill
    final fillPath = Path.from(curvePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accentRed.withValues(alpha: 0.3),
            AppColors.accentRed.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Curve stroke
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = AppColors.accentRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // End dot
    canvas.drawCircle(
      points.last,
      4,
      Paint()
        ..color = AppColors.accentRed
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PersonalTrendPainter oldDelegate) =>
      values != oldDelegate.values;
}
