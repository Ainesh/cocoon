/// Health details bottom sheet showing detailed relationship health metrics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_checkin.dart';
import '../../../theme/theme.dart';

/// Shows detailed health score breakdown in a modal bottom sheet.
void showHealthDetailsSheet({
  required BuildContext context,
  required CheckInStats checkInStats,
  required int streak,
  required List<Map<String, dynamic>>? dailyScores,
}) {
  // Scores are 1-10, convert to 0-100 scale
  final connectionPct = checkInStats.avgConnection * 10;
  final intimacyPct = checkInStats.avgIntimacy * 10;
  final peacePct = checkInStats.avgPeace * 10;
  
  final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3).round();
  final remark = _getHealthRemark(overallHealth);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _HealthDetailsContent(
      overallHealth: overallHealth,
      remark: remark,
      connectionPct: connectionPct,
      intimacyPct: intimacyPct,
      peacePct: peacePct,
      checkInStats: checkInStats,
      streak: streak,
      dailyScores: dailyScores,
    ),
  );
}

String _getHealthRemark(int score) {
  if (score >= 85) return 'Deeply Connected';
  if (score >= 70) return 'Thriving Together';
  if (score >= 50) return 'Growing Stronger';
  if (score >= 30) return 'Room to Grow';
  return 'Needs Attention';
}

/// Gets a single word summary of the relationship trend over the month.
String _getMonthSummary(CheckInStats stats, List<Map<String, dynamic>>? dailyScores) {
  if (stats.checkInCount < 2) return 'Starting';
  
  // Calculate overall trend from the three dimensions
  final overallTrend = (stats.connectionTrend + stats.intimacyTrend + stats.peaceTrend) / 3;
  
  // Calculate variance from daily scores if available
  double variance = 0;
  if (dailyScores != null && dailyScores.isNotEmpty) {
    final scores = dailyScores
        .where((d) => d['hasCheckIn'] == true)
        .map((d) => (d['score'] as double?) ?? 0)
        .toList();
    if (scores.length >= 2) {
      final mean = scores.reduce((a, b) => a + b) / scores.length;
      variance = scores.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / scores.length;
    }
  }
  
  // Calculate average health
  final avgHealth = ((stats.avgConnection * 10) + 
                     (stats.avgIntimacy * 10) + 
                     (stats.avgPeace * 10)) / 3;
  
  // Determine summary based on trend, variance, and health
  if (variance > 400) {
    // High variance = turbulent
    return 'Turbulent';
  } else if (overallTrend > 0.3 && avgHealth >= 70) {
    return 'Blossoming';
  } else if (overallTrend > 0.15) {
    return 'Improving';
  } else if (overallTrend < -0.3) {
    return 'Challenging';
  } else if (overallTrend < -0.15) {
    return 'Cooling';
  } else if (avgHealth >= 80 && variance < 100) {
    return 'Harmonious';
  } else if (avgHealth >= 65 && variance < 150) {
    return 'Smooth';
  } else if (avgHealth >= 50) {
    return 'Steady';
  } else {
    return 'Rebuilding';
  }
}

class _HealthDetailsContent extends StatelessWidget {
  const _HealthDetailsContent({
    required this.overallHealth,
    required this.remark,
    required this.connectionPct,
    required this.intimacyPct,
    required this.peacePct,
    required this.checkInStats,
    required this.streak,
    required this.dailyScores,
  });

  final int overallHealth;
  final String remark;
  final double connectionPct;
  final double intimacyPct;
  final double peacePct;
  final CheckInStats checkInStats;
  final int streak;
  final List<Map<String, dynamic>>? dailyScores;

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
          color: AppColors.darkCardLight,
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
                    overallHealth.toString(),
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
                    'The health card is a uniquely generated artifact using the data below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Two columns: Left insights, Right attributes
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Insights (tappable for help)
                        Expanded(child: _buildInsightsCard(context)),
                        const SizedBox(width: 12),
                        // Right: Attribute breakdown
                        Expanded(child: _buildAttributesColumn()),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Monthly trend chart
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
    final monthSummary = _getMonthSummary(checkInStats, dailyScores);
    
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
                  style: GoogleFonts.inter(
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
                    text: monthSummary,
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
            _buildInsightRow('Your check-ins', checkInStats.userCheckInCount.toString(), ''),
            const SizedBox(height: 12),
            _buildInsightRow('Partner check-ins', checkInStats.partnerCheckInCount.toString(), ''),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppColors.accentRed, size: 16),
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
        backgroundColor: AppColors.darkCard,
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
                    child: Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentRed, size: 20),
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
              _buildGlossaryItem('Blossoming', 'High scores & improving trend'),
              _buildGlossaryItem('Harmonious', 'Consistently high scores'),
              _buildGlossaryItem('Smooth', 'Good scores & stable'),
              _buildGlossaryItem('Improving', 'Scores trending upward'),
              _buildGlossaryItem('Steady', 'Moderate & consistent'),
              _buildGlossaryItem('Cooling', 'Slight downward trend'),
              _buildGlossaryItem('Challenging', 'Significant decline'),
              _buildGlossaryItem('Turbulent', 'Fluctuating scores'),
              _buildGlossaryItem('Rebuilding', 'Working through lows'),
              _buildGlossaryItem('Starting', 'Need more check-ins'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentRed.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildInsightRow(String label, String value, String suffix) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.warmDim,
            fontSize: 13,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (suffix.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                suffix,
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Score colour on the blue (low) → red (high) spectrum.
  Color _scoreColor(double pct) =>
      Color.lerp(AppColors.morningColor, AppColors.nightColor,
          (pct / 100).clamp(0.0, 1.0)) ??
      AppColors.nightColor;

  Widget _buildAttributesColumn() {
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
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _buildPulseRow(
            Icons.favorite_rounded,
            null,
            'Connection',
            connectionPct,
            checkInStats.connectionTrend,
          ),
          const SizedBox(height: 12),
          _buildPulseRow(
            null,
            'assets/icons/flame.svg',
            'Intimacy',
            intimacyPct,
            checkInStats.intimacyTrend,
          ),
          const SizedBox(height: 12),
          _buildPulseRow(
            null,
            'assets/icons/peace.svg',
            'Peace',
            peacePct,
            checkInStats.peaceTrend,
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRow(
    IconData? icon,
    String? svgPath,
    String label,
    double value,
    double trend,
  ) {
    final color = _scoreColor(value);
    final trendPositive = trend > 0;
    final trendColor =
        trendPositive ? AppColors.success : AppColors.trendNegative;

    return Row(
      children: [
        // Icon coloured by score
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: color, size: 16)
                : SvgPicture.asset(
                    svgPath!,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // Label
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.warmDim,
              fontSize: 13,
            ),
          ),
        ),
        // Score (smaller) + trend arrow
        Text(
          value.round().toString(),
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trend != 0) ...[
          const SizedBox(width: 4),
          Icon(
            trendPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: trendColor,
            size: 12,
          ),
        ],
      ],
    );
  }

  Widget _buildMonthlyTrendChart() {
    final scores = dailyScores ?? [];
    final hasData = scores.isNotEmpty && scores.any((d) => d['hasCheckIn'] == true);
    
    // Calculate weekly averages (4 weeks from 30 days)
    // Week 1: days 0-6, Week 2: days 7-13, Week 3: days 14-20, Week 4: days 21-29
    final weeklyAverages = <double>[];
    final weekRanges = [
      [0, 7],   // Week 1 (oldest)
      [7, 14],  // Week 2
      [14, 21], // Week 3
      [21, 30], // Week 4 (most recent, includes today)
    ];
    
    for (final range in weekRanges) {
      double sum = 0;
      int checkInCount = 0;
      for (int i = range[0]; i < range[1] && i < scores.length; i++) {
        final hasCheckIn = scores[i]['hasCheckIn'] as bool? ?? false;
        if (hasCheckIn) {
          final score = scores[i]['score'] as double? ?? 0;
          sum += score;
          checkInCount++;
        }
      }
      // Average only from days with check-ins, 0 if no check-ins in week
      weeklyAverages.add(checkInCount > 0 ? sum / checkInCount : 0);
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading inside card
          Text(
            'TREND',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // Chart area
          SizedBox(
            height: 80,
            child: hasData
                ? CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _WeeklyBarChartPainter(
                      values: weeklyAverages,
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
          
          // X-axis labels
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
                  color: AppColors.warmLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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
    
    // Calculate point heights (scaled to 0-100 -> 0-height)
    final heights = values.map((v) => (v / 100) * size.height).toList();
    
    // Calculate evenly spaced x positions
    final points = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final x = (i / (pointCount - 1)) * size.width;
      points.add(Offset(x, size.height - heights[i]));
    }

    // Draw smooth curve
    if (heights.any((h) => h > 0)) {
      final curvePath = Path();
      
      curvePath.moveTo(points.first.dx, points.first.dy);
      
      // Draw smooth bezier curves between points
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
      
      // Close path for fill
      final fillPath = Path.from(curvePath);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      
      // Draw gradient fill under curve
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

      // Draw curve line
      final curvePaint = Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(curvePath, curvePaint);
      
      // Draw dot at the last point (this week)
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
