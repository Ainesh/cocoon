/// A card component that shows active state through heading color.
///
/// When [isActive] is true:
/// - Heading turns red
/// - Helper text can optionally be hidden
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A card with a heading that highlights when active.
///
/// Use this for form sections that should indicate engagement/modification.
class ActiveCard extends StatelessWidget {
  const ActiveCard({
    super.key,
    required this.heading,
    required this.isActive,
    required this.child,
    this.helperText,
    this.hideHelperWhenActive = true,
    this.shrinkWhenActive = false,
    this.showBorder = false,
    this.transparent = false,
  });

  /// The heading text (displayed in UPPERCASE with letter spacing)
  final String heading;
  
  /// Whether the card is in active/modified state (controls heading color & helper visibility)
  final bool isActive;
  
  /// The main content of the card
  final Widget child;
  
  /// Optional helper text shown below the heading
  final String? helperText;
  
  /// If true, helper text is hidden when active (default: true)
  final bool hideHelperWhenActive;
  
  /// If true, card shrinks when helper is hidden. If false, helper fades but keeps space.
  final bool shrinkWhenActive;
  
  /// If true, shows a red border (can be controlled separately from isActive)
  final bool showBorder;

  /// If true, uses a transparent background (for use over custom backgrounds).
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final hideHelper = hideHelperWhenActive && isActive;
    final showHelperSpace = helperText != null && (!hideHelper || !shrinkWhenActive);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showBorder
              ? AppColors.accentRed.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading - turns red when active
          Text(
            heading.toUpperCase(),
            style: GoogleFonts.outfit(
              color: isActive ? AppColors.accentRed : AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          // Helper text - either fades (keeps space) or removes (shrinks) based on shrinkWhenActive
          if (showHelperSpace) ...[
            const SizedBox(height: 4),
            if (shrinkWhenActive)
              // Just show/hide - card will shrink
              Text(
                helperText!,
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              )
            else
              // Fade but keep space
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: hideHelper ? 0.0 : 1.0,
                child: Text(
                  helperText!,
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          SizedBox(height: showHelperSpace ? 12 : 8),
          // Content
          child,
        ],
      ),
    );
  }
}
