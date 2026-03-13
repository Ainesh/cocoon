/// Dashboard card prompting users to create memories for past moments.
///
/// Positioned below the main grid and above the activity trail.
/// Uses [ActionButton] for the "Create Memory" CTA to match the style
/// of Plan a Moment and Check-in buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/moment.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/moment_type_icon.dart';

class MemoryPromptCard extends StatelessWidget {
  const MemoryPromptCard({
    super.key,
    required this.moment,
    required this.onCreateMemory,
    required this.onMissed,
    required this.onSkip,
  });

  final Moment moment;
  final VoidCallback onCreateMemory;
  final VoidCallback onMissed;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Moment context card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REMEMBER',
                style: GoogleFonts.outfit(
                  color: AppColors.accentRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  getMomentTypeIconWidget(moment.type, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moment.name,
                          style: AppTypography.headlineSmall(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppDateFormat.short(moment.startDate),
                          style: AppTypography.bodySmall(color: AppColors.warmDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Secondary actions: Didn't happen + Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onMissed();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Didn't happen",
                        style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSkip();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Primary CTA — ActionButton matching Plan a Moment / Check-in style
        ActionButton(
          label: 'Seal a memory',
          icon: Icons.auto_stories_rounded,
          onTap: onCreateMemory,
        ),
      ],
    );
  }
}
