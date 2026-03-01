/// Thin segmented progress bar for the onboarding setup phase.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Instagram Stories-style segmented progress bar.
///
/// Completed segments fill with [activeColor], the current segment
/// animates its fill, and future segments remain dim.
class StoryProgressBar extends StatelessWidget {
  const StoryProgressBar({
    super.key,
    required this.totalSegments,
    required this.currentSegment,
    this.activeColor,
    this.inactiveColor,
    this.height = 3.0,
    this.gap = 6.0,
  });

  final int totalSegments;

  /// Zero-based index of the current segment.
  final int currentSegment;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.refinedRed;
    final inactive =
        inactiveColor ?? AppColors.dimText.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSegments, (i) {
          final isCompleted = i < currentSegment;
          final isCurrent = i == currentSegment;

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i < totalSegments - 1 ? gap : 0),
              height: height,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? active : inactive,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
