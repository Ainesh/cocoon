/// Moment group header for the memories timeline.
///
/// Displays the moment name, type icon, and date as a header above
/// grouped memory cards from both partners.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/moment.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'moment_type_icon.dart';

/// Header shown above memory cards that share the same linked moment.
class MomentGroupHeader extends StatelessWidget {
  const MomentGroupHeader({
    super.key,
    required this.momentName,
    this.momentType,
    required this.date,
  });

  final String momentName;
  final String? momentType;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final type = momentType != null
        ? MomentType.fromValue(momentType!)
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          if (type != null) ...[
            getMomentTypeIconWidget(type, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              momentName,
              style: GoogleFonts.outfit(
                color: AppColors.lightText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppDateFormat.compact(date),
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
