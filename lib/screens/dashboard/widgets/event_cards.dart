/// Moment display cards for the dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/moment.dart';
import '../../../theme/theme.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/moment_type_icon.dart';

/// Card showing upcoming moments ("Coming Up").
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({
    super.key,
    required this.moments,
    this.onTap,
    this.onMomentTap,
    this.onMoreTap,
  });

  /// Upcoming moments (shows up to 4).
  final List<Moment> moments;
  
  /// Callback when card header is tapped.
  final VoidCallback? onTap;
  
  /// Callback when a specific moment is tapped.
  final void Function(Moment moment)? onMomentTap;
  
  /// Callback when "more" indicator is tapped.
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    // Show up to 3 moments to prevent overflow
    final displayMoments = moments.take(3).toList();
    final hasMore = moments.length > 3;
    
    return Container(
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
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Coming Up',
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          
          // Content
          if (displayMoments.isNotEmpty) ...[
            // Show up to 4 moments with dividers
            for (int i = 0; i < displayMoments.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    color: AppColors.warmMuted.withValues(alpha: 0.15),
                    height: 1,
                  ),
                ),
              _MomentPreview(
                moment: displayMoments[i],
                isSecondary: i > 0,
                onTap: onMomentTap != null ? () => onMomentTap!(displayMoments[i]) : null,
              ),
            ],
            
            // "More" indicator if there are more moments
            if (hasMore) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: onMoreTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+${moments.length - 3} more',
                        style: GoogleFonts.inter(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.accentRed,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else
            Center(
              child: Text(
                'No moments planned',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Preview of a moment within the Coming Up card.
class _MomentPreview extends StatelessWidget {
  const _MomentPreview({
    required this.moment,
    this.isSecondary = false,
    this.onTap,
  });

  final Moment moment;
  final bool isSecondary;
  final VoidCallback? onTap;

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
    final iconSize = isSecondary ? 14.0 : 16.0;
    final containerSize = isSecondary ? 24.0 : 28.0;
    
    return GestureDetector(
      onTap: onTap != null ? () {
        HapticFeedback.selectionClick();
        onTap!();
      } : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Flat icon in container
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: getMomentTypeIconWidget(
                moment.type,
                size: iconSize,
                color: AppColors.accentRed,
              ),
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
                    fontSize: isSecondary ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _dateLabel,
                  style: GoogleFonts.inter(
                    color: AppColors.warmDim,
                    fontSize: isSecondary ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Chevron indicator
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.warmMuted.withValues(alpha: 0.5),
              size: isSecondary ? 16 : 18,
            ),
        ],
      ),
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
    return ActionButton(
      label: 'Plan a moment',
      onTap: onTap,
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
    return ActionButton(
      label: 'Check in',
      onTap: onTap,
    );
  }
}
