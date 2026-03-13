/// Dashboard card prompting users about past moments.
///
/// Simple binary choice: did you live it or miss it?
/// - "Lived it" → marks moment as lived + navigates to create memory
/// - "Missed it" → marks moment as missed + dismisses the prompt
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/moment.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/moment_type_icon.dart';

class MemoryPromptCard extends StatelessWidget {
  const MemoryPromptCard({
    super.key,
    required this.moment,
    required this.onLived,
    required this.onMissed,
  });

  final Moment moment;
  final VoidCallback onLived;
  final VoidCallback onMissed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'HOW WAS IT?',
            style: GoogleFonts.outfit(
              color: AppColors.accentRed,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Moment context
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

          // Two actions
          Row(
            children: [
              // Lived it — primary
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onLived();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Lived it',
                        style: GoogleFonts.outfit(
                          color: AppColors.accentRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Missed it — secondary
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onMissed();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.cardVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Missed it',
                        style: GoogleFonts.inter(
                          color: AppColors.warmDim,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
