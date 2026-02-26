/// Health details bottom sheet — fully dynamic from ScoreResult.
///
/// Shows overall score, dynamic pulse attribute rows, simplified insight
/// labels (6 total), and a weekly trend chart. Everything scoped to 30 days.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/pulse_config.dart';
import '../../../scoring/score_models.dart';
import '../../../theme/theme.dart';

/// Shows detailed health score breakdown in a modal bottom sheet.
void showHealthDetailsSheet({
  required BuildContext context,
  required ScoreResult scoreResult,
  required int streak,
}) {
  final remark = _getHealthRemark(scoreResult.overallScore);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _HealthDetailsContent(
      scoreResult: scoreResult,
      remark: remark,
      streak: streak,
    ),
  );
}

/// Score-magnitude remark (distinct from trend-based insight labels).
String _getHealthRemark(int score) {
  if (score >= 85) return 'Deeply Connected';
  if (score >= 70) return 'In a Good Place';
  if (score >= 50) return 'Building Together';
  if (score >= 30) return 'Room to Bloom';
  return 'Time to Reconnect';
}

class _HealthDetailsContent extends StatelessWidget {
  const _HealthDetailsContent({
    required this.scoreResult,
    required this.remark,
    required this.streak,
  });

  final ScoreResult scoreResult;
  final String remark;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Swipe down to close
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.pureBlack,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Heading
                    Text(
                      'Relationship Health Score',
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Top: Centered score
                    Text(
                      scoreResult.overallScore.toString(),
                      style: GoogleFonts.outfit(
                        color: AppColors.accentRed,
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remark,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.warmLight,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Helper text
                    Text(
                      'The mosaic is a live artifact that represents the health of the space using data below.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.warmMuted.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Insights + Pulse Score side by side
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildInsightsCard(context)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAttributesColumn()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Trend chart card
                    _buildMonthlyTrendChart(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInsightsHelp(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with info indicator
            Row(
              children: [
                Text(
                  'INSIGHTS',
                  style: GoogleFonts.outfit(
                    color: AppColors.warmMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Glowing info dot - indicates tappable
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.accentRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentRed.withValues(alpha: 0.9),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: AppColors.accentRed.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Pulse summary - left aligned
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: scoreResult.insight.displayName,
                    style: GoogleFonts.outfit(
                      color: AppColors.accentRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' over last 30 days',
                    style: GoogleFonts.inter(
                      color: AppColors.warmLight,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              'Your check-ins',
              scoreResult.userCheckInCount.toString(),
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              'Partner check-ins',
              scoreResult.partnerCheckInCount.toString(),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.accentRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streak day streak',
                    style: GoogleFonts.outfit(
                      color: AppColors.accentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInsightsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.darkCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.accentRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Understanding Insights',
                    style: GoogleFonts.outfit(
                      color: AppColors.warmLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'The pulse describes your relationship\'s rhythm over time:',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 6 reduced labels
              for (final label in InsightLabel.values)
                _buildGlossaryItem(label.displayName, label.description),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentRed.withValues(
                      alpha: 0.15,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.outfit(
                      color: AppColors.accentRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _buildGlossaryItem(String word, String meaning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              word,
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              meaning,
              style: GoogleFonts.inter(
                color: AppColors.warmMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Score colour on the blue (low) → red (high) spectrum.
  Color _scoreColor(double pct) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        (pct / 100).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;


  Widget _buildAttributesColumn() {
    // Dynamic attribute rows from ScoreResult
    final attrIds = scoreResult.attributeScores.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PULSE SCORE',
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < attrIds.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildPulseRow(
              attrIds[i],
              scoreResult.attributeScores[attrIds[i]] ?? 0,
              scoreResult.attributeTrends[attrIds[i]] ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPulseRow(String attrId, double value, double trend) {
    final attr = PulseAttribute.fromId(attrId);
    final color = _scoreColor(value);
    final label = attr?.displayName ?? attrId;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: attr != null
                ? attr.buildIcon(color: color, size: 14)
                : Icon(Icons.circle, color: color, size: 14),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 11),
          ),
        ),
        Text(
          value.round().toString(),
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendChart() {
    final weeklyScores = scoreResult.weeklyScores;
    final hasData = weeklyScores.any((w) => w.hasData);

    final weeklyValues =
        weeklyScores.map((w) => w.overallScore).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TREND',
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: hasData
                ? CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _WeeklyBarChartPainter(
                      values: weeklyValues,
                      barColor: AppColors.accentRed,
                      curveColor: AppColors.accentRed,
                    ),
                  )
                : Center(
                    child: Text(
                      'No check-ins yet',
                      style: GoogleFonts.inter(
                        color: AppColors.warmMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Some time back',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                'Now',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for smooth area curve chart.
class _WeeklyBarChartPainter extends CustomPainter {
  _WeeklyBarChartPainter({
    required this.values,
    required this.barColor,
    required this.curveColor,
  });

  final List<double> values;
  final Color barColor;
  final Color curveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final pointCount = values.length;
    final heights = values.map((v) => (v / 100) * size.height).toList();

    final points = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final x = pointCount > 1
          ? (i / (pointCount - 1)) * size.width
          : size.width / 2;
      points.add(Offset(x, size.height - heights[i]));
    }

    if (heights.any((h) => h > 0)) {
      final curvePath = Path();
      curvePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 4;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 4;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 4;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 4;

        curvePath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      final fillPath = Path.from(curvePath);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor.withValues(alpha: 0.35),
            barColor.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      final curvePaint = Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(curvePath, curvePaint);

      final dotPaint = Paint()
        ..color = curveColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.last, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) {
    return values != oldDelegate.values;
  }
}
