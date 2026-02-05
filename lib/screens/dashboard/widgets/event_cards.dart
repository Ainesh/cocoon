/// Moment display cards for the dashboard.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/moment.dart';
import '../../../theme/theme.dart';

/// Card showing upcoming moments ("Coming Up").
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({
    super.key,
    required this.moments,
    this.onTap,
  });

  /// Upcoming moments.
  final List<Moment> moments;
  
  /// Callback when card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            // Header
            Text(
              'Coming Up',
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            
            // Content
            if (moments.isNotEmpty) ...[
              // First moment
              _MomentPreview(moment: moments.first),
              
              // Second moment (if exists)
              if (moments.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: AppColors.warmMuted.withValues(alpha: 0.2),
                    height: 1,
                  ),
                ),
                _MomentPreview(moment: moments[1], isSecondary: true),
              ],
            ] else
              Text(
                'No moments planned',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Preview of a moment within the Coming Up card.
class _MomentPreview extends StatelessWidget {
  const _MomentPreview({
    required this.moment,
    this.isSecondary = false,
  });

  final Moment moment;
  final bool isSecondary;

  String get _dateLabel {
    final relative = moment.relativeDate;
    
    // Add time slot for connect moments
    if (moment.type == MomentType.connect && moment.timeSlot != null) {
      return '$relative, ${moment.timeSlot!.label.toLowerCase()}';
    }
    
    // Add duration for escape moments
    if (moment.type == MomentType.escape && moment.nights > 0) {
      return '$relative (${moment.nights} nights)';
    }
    
    return relative;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Emoji
        Text(
          moment.type.emoji,
          style: TextStyle(
            fontSize: isSecondary ? 16 : 20,
          ),
        ),
        const SizedBox(width: 10),
        
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                moment.name,
                style: GoogleFonts.inter(
                  color: isSecondary ? AppColors.warmMuted : AppColors.warmLight,
                  fontSize: isSecondary ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _dateLabel,
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: isSecondary ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plan a Moment button card.
class PlanMomentCard extends StatelessWidget {
  const PlanMomentCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Plan a moment',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.play_circle_filled_rounded,
              color: AppColors.accentRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Check-in button card.
class CheckInCard extends StatelessWidget {
  const CheckInCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Check in',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.play_circle_filled_rounded,
              color: AppColors.accentRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
