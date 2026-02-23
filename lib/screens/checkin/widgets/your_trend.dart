/// Your trend chart widget.
///
/// Displays a chart showing the user's check-in history
/// with connection and intimacy trends.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../models/user_checkin.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/painters/trend_chart_painter.dart';
import '../../../widgets/neumorphic_container.dart';

/// Displays a trend chart for the user's recent check-ins.
class YourTrendChart extends StatelessWidget {
  const YourTrendChart({super.key, required this.checkIns, this.maxItems = 8});

  /// User's check-ins (will be limited to [maxItems])
  final List<UserCheckIn> checkIns;

  /// Maximum number of check-ins to display (default: 8)
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final displayCheckIns = checkIns.take(maxItems).toList().reversed.toList();

    if (displayCheckIns.isEmpty) {
      return const SizedBox.shrink();
    }

    final connectionValues = displayCheckIns
        .map((c) => c.connection.toDouble())
        .toList();
    final intimacyValues = displayCheckIns
        .map((c) => c.intimacy.toDouble())
        .toList();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Your Trend',
          ),
          const SizedBox(height: 8),
          Text(
            'Last ${displayCheckIns.length} check-ins',
            style: AppTypography.labelSmall(color: AppColors.warmMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: TrendChartPainter(
                primaryValues: connectionValues,
                secondaryValues: intimacyValues,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.accentRed,
                  size: 14,
                ),
                label: 'Connection',
                color: AppColors.accentRed,
              ),
              const SizedBox(width: 24),
              _LegendItem(
                icon: SvgPicture.asset(
                  'assets/icons/flame.svg',
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    AppColors.morningColor,
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Intimacy',
                color: AppColors.morningColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('M/d').format(displayCheckIns.first.timestamp),
                style: AppTypography.labelSmall(color: AppColors.warmMuted),
              ),
              Text(
                'Latest',
                style: AppTypography.labelSmall(color: AppColors.warmLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final Widget icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: icon,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMedium(color: AppColors.warmLight),
        ),
      ],
    );
  }
}
