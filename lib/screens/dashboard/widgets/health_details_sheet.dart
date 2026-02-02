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
  final peacePct = (10 - checkInStats.avgStress) * 10;
  
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
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
                  const SizedBox(height: 32),
                  
                  // Two columns: Left insights, Right attributes
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Insights
                        Expanded(child: _buildInsightsCard()),
                        const SizedBox(width: 12),
                        // Right: Attribute breakdown
                        Expanded(child: _buildAttributesColumn()),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Trend visualization
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'WEEKLY TREND',
                      style: GoogleFonts.inter(
                        color: AppColors.warmMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTrendChart(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
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
            'INSIGHTS',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightRow('Past 30 Days', checkInStats.checkInCount.toString(), 'total'),
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

  Widget _buildAttributesColumn() {
    return Column(
      children: [
        Expanded(
          child: _buildCompactMetric(
            'Connection',
            Icons.favorite_rounded,
            null,
            connectionPct,
            checkInStats.connectionTrend,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildCompactMetricSvg(
            'Intimacy',
            'assets/icons/flame.svg',
            intimacyPct,
            checkInStats.intimacyTrend,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildCompactMetricSvg(
            'Peace',
            'assets/icons/peace.svg',
            peacePct,
            -checkInStats.stressTrend,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMetric(String label, IconData? icon, String? svgPath, double value, double trend) {
    final trendPositive = trend > 0;
    final trendColor = trendPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon != null 
                ? Icon(icon, color: AppColors.accentRed, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 11,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value.round().toString(),
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trend != 0) ...[
                      const SizedBox(width: 6),
                      Icon(
                        trendPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: trendColor,
                        size: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricSvg(String label, String svgPath, double value, double trend) {
    final trendPositive = trend > 0;
    final trendColor = trendPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: SvgPicture.asset(
                svgPath,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(AppColors.accentRed, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 11,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value.round().toString(),
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trend != 0) ...[
                      const SizedBox(width: 6),
                      Icon(
                        trendPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: trendColor,
                        size: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final scores = dailyScores ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayData = index < scores.length ? scores[index] : null;
              final score = dayData?['score'] as double? ?? 0;
              final hasCheckIn = dayData?['hasCheckIn'] as bool? ?? false;
              final date = dayData?['date'] as DateTime?;
              
              final height = hasCheckIn ? (10 + (score * 0.7)).clamp(10.0, 80.0) : 10.0;
              final isToday = index == 6;
              
              final dayLabel = date != null 
                  ? dayLabels[date.weekday - 1] 
                  : dayLabels[index];
              
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: height,
                    decoration: BoxDecoration(
                      color: hasCheckIn 
                          ? (isToday ? AppColors.accentRed : AppColors.accentRed.withValues(alpha: 0.6))
                          : AppColors.warmMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayLabel,
                    style: GoogleFonts.inter(
                      color: isToday ? AppColors.warmLight : AppColors.warmMuted,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (scores.isEmpty || !scores.any((d) => d['hasCheckIn'] == true))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No check-ins this week',
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
}
