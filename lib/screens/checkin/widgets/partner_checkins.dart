/// Partner check-ins timeline widget.
///
/// Displays a timeline view of partner's recent check-ins
/// with scores for each dimension.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

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
            child: CircularProgressIndicator(color: AppColors.accentRed, strokeWidth: 2),
          ),
        ),
      );
    }

    if (checkIns.isEmpty) {
      return PremiumCard(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.people_outline_rounded, color: AppColors.warmMuted, size: 48),
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
  const _TimelineItem({
    required this.checkIn,
    this.isLast = false,
  });

  final UserCheckIn checkIn;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final connectionPct = checkIn.connection * 10;
    final intimacyPct = checkIn.intimacy * 10;
    final peacePct = checkIn.peace * 10;

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
              Container(
                width: 1,
                height: 52,
                color: AppColors.cardVariant,
              ),
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
                // Scores inline
                Row(
                  children: [
                    _InlineScore(icon: Icons.favorite_rounded, value: connectionPct.round()),
                    const SizedBox(width: 16),
                    _InlineScoreSvg(svgPath: 'assets/icons/flame.svg', value: intimacyPct.round()),
                    const SizedBox(width: 16),
                    _InlineScoreSvg(svgPath: 'assets/icons/peace.svg', value: peacePct.round()),
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

class _InlineScore extends StatelessWidget {
  const _InlineScore({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentRed, size: 16),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.warmLight,
          ),
        ),
      ],
    );
  }
}

class _InlineScoreSvg extends StatelessWidget {
  const _InlineScoreSvg({required this.svgPath, required this.value});

  final String svgPath;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          svgPath,
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(AppColors.accentRed, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.warmLight,
          ),
        ),
      ],
    );
  }
}
