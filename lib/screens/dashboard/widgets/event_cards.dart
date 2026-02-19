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
/// Shows max 2 events: first featured (large), second compact.
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({
    super.key,
    required this.moments,
    this.onTap,
    this.onMomentTap,
  });

  /// Upcoming moments (shows up to 2).
  final List<Moment> moments;
  
  /// Callback when card header is tapped.
  final VoidCallback? onTap;
  
  /// Callback when a specific moment is tapped.
  final void Function(Moment moment)? onMomentTap;

  @override
  Widget build(BuildContext context) {
    final firstMoment = moments.isNotEmpty ? moments.first : null;
    final secondMoment = moments.length > 1 ? moments[1] : null;
    
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
              'COMING UP',
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 14),
          
          // Content - fixed sizes, extra space goes to bottom
          if (firstMoment != null) ...[
            // Featured moment (first/next up) - fixed size
            _FeaturedMomentPreview(
              moment: firstMoment,
              onTap: onMomentTap != null ? () => onMomentTap!(firstMoment) : null,
            ),
            
            // Second moment (compact)
            if (secondMoment != null) ...[
              const SizedBox(height: 20),
              Divider(
                color: AppColors.warmMuted.withValues(alpha: 0.15),
                height: 1,
              ),
              const SizedBox(height: 12),
              _CompactMomentPreview(
                moment: secondMoment,
                onTap: onMomentTap != null ? () => onMomentTap!(secondMoment) : null,
              ),
              // Show additional events count - pushed to bottom
              if (moments.length > 2) ...[
                const Spacer(),
                Divider(
                  color: AppColors.warmMuted.withValues(alpha: 0.15),
                  height: 1,
                ),
                const SizedBox(height: 10),
                Text(
                  '+ ${moments.length - 2} moments this month',
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ] else
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nothing',
                      style: GoogleFonts.inter(
                        color: AppColors.warmDim,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.heart_broken_rounded,
                      color: AppColors.warmDim,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Featured moment preview - larger with more details.
/// Layout: Name (full width) on top, then icon + date info below.
class _FeaturedMomentPreview extends StatelessWidget {
  const _FeaturedMomentPreview({
    required this.moment,
    this.onTap,
  });

  final Moment moment;
  final VoidCallback? onTap;

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Returns date info, potentially on two lines for escape moments
  List<String> get _dateInfoLines {
    final date = moment.startDate;
    final dayName = _dayNames[date.weekday - 1];
    
    // For escape moments, just show date range (no day name)
    if (moment.type == MomentType.escape) {
      return [moment.dateDisplay]; // ["Feb 7 - Feb 9"]
    }
    
    // Single line for other moments with day name
    return ['${moment.dateDisplay}, $dayName'];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () {
        HapticFeedback.selectionClick();
        onTap!();
      } : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name - full width at top
          Text(
            moment.name,
            style: GoogleFonts.outfit(
              color: AppColors.warmLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Icon + details row
          Row(
            children: [
              // Icon container - larger for better visual balance
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: getMomentTypeIconWidget(
                    moment.type,
                    size: 22,
                    color: AppColors.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Date info - wrapped to take available space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.relativeDate,
                      style: GoogleFonts.inter(
                        color: AppColors.accentRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Date info (may be multiple lines for escape moments)
                    ..._dateInfoLines.map((line) => Text(
                      line,
                      style: GoogleFonts.inter(
                        color: AppColors.warmDim,
                        fontSize: 12,
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact moment preview - minimal details.
class _CompactMomentPreview extends StatelessWidget {
  const _CompactMomentPreview({
    required this.moment,
    this.onTap,
  });

  final Moment moment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () {
        HapticFeedback.selectionClick();
        onTap!();
      } : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Small icon container
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: getMomentTypeIconWidget(
                moment.type,
                size: 14,
                color: AppColors.accentRed,
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Name and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moment.name,
                  style: GoogleFonts.inter(
                    color: AppColors.warmLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  moment.relativeDate,
                  style: GoogleFonts.inter(
                    color: AppColors.warmDim,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plan a Moment button card.
/// Can expand to fill available space when [expanded] is true.
class PlanMomentCard extends StatelessWidget {
  const PlanMomentCard({
    super.key,
    required this.onTap,
    this.expanded = false,
  });

  final VoidCallback onTap;
  
  /// Whether the button should expand to fill available height.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return ActionButton(
      label: 'Plan a moment',
      icon: Icons.add_circle_rounded,
      layout: expanded ? ActionButtonLayout.vertical : ActionButtonLayout.horizontal,
      expanded: expanded,
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
