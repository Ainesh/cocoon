/// Partner check-ins timeline widget.
///
/// Displays a timeline view of partner's recent check-ins
/// with dynamic attribute scores from each check-in's scores map.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/pulse_config.dart';
import '../../../models/user_checkin.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/neumorphic_container.dart';

/// Displays partner's recent check-ins in a timeline format.
class PartnerCheckIns extends StatelessWidget {
  const PartnerCheckIns({
    super.key,
    required this.checkIns,
    required this.partnerName,
    required this.isLoading,
  });

  /// List of partner's check-ins to display
  final List<UserCheckIn> checkIns;

  /// Partner's display name
  final String? partnerName;

  /// Whether data is still loading
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return PremiumCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(
              color: AppColors.accentRed,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (checkIns.isEmpty) {
      return PremiumCard(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(
              Icons.people_outline_rounded,
              color: AppColors.warmMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No partner check-ins yet',
              style: AppTypography.titleMedium(color: AppColors.warmLight),
            ),
            const SizedBox(height: 8),
            Text(
              'When your partner checks in, you\'ll see their scores here.',
              style: AppTypography.bodySmall(color: AppColors.warmMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with partner's avatar and name
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.accentRed,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                partnerName ?? 'Partner',
                style: AppTypography.headlineSmall(color: AppColors.warmLight),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Simple timeline list
          ...checkIns.asMap().entries.map((entry) {
            final index = entry.key;
            final checkIn = entry.value;
            final isLast = index == checkIns.length - 1;
            return _TimelineItem(checkIn: checkIn, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.checkIn, this.isLast = false});

  final UserCheckIn checkIn;
  final bool isLast;

  /// Score colour on the blue → red spectrum (1-100 scale).
  Color _scoreColor(int score) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((score - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  Widget _buildScoreIcon(PulseAttribute attr, int score) {
    return attr.buildIcon(color: _scoreColor(score), size: 16);
  }

  @override
  Widget build(BuildContext context) {
    // Render dynamic scores from the check-in's scores map
    final activeAttrs = checkIn.configSnapshot.activeAttributes
        .map((id) => PulseAttribute.fromId(id))
        .whereType<PulseAttribute>()
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 1, height: 52, color: AppColors.cardVariant),
          ],
        ),
        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time
                Text(
                  checkIn.timeAgo,
                  style: AppTypography.labelSmall(color: AppColors.warmMuted),
                ),
                const SizedBox(height: 8),
                // Scores inline — dynamic attributes
                Row(
                  children: [
                    for (int i = 0; i < activeAttrs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildScoreIcon(
                            activeAttrs[i],
                            checkIn.scores[activeAttrs[i].id] ?? 50,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${checkIn.scores[activeAttrs[i].id] ?? 50}',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warmLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

