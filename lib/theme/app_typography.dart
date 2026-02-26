/// Centralized typography definitions for Kairos app.
///
/// Use these text styles throughout the app for consistency.
/// Import: `import 'package:couple_space/theme/app_typography.dart';`
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Kairos app typography styles.
abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // Font Families
  // ---------------------------------------------------------------------------

  /// Display font family (Outfit) - for headlines and scores.
  static String get displayFontFamily => GoogleFonts.outfit().fontFamily!;

  /// Body font family (Inter) - for body text and descriptions.
  static String get bodyFontFamily => GoogleFonts.inter().fontFamily!;

  /// Tagline font family (Cormorant Garamond) - for elegant remarks.
  static String get taglineFontFamily =>
      GoogleFonts.cormorantGaramond().fontFamily!;

  // ---------------------------------------------------------------------------
  // Display Styles (Outfit)
  // ---------------------------------------------------------------------------

  /// Large display text (56px, bold).
  static TextStyle displayLarge({Color? color}) => GoogleFonts.outfit(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    color: color ?? AppColors.lightText,
  );

  /// Medium display text (44px, semi-bold).
  static TextStyle displayMedium({Color? color}) => GoogleFonts.outfit(
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: color ?? AppColors.lightText,
  );

  /// Small display text (36px, semi-bold).
  static TextStyle displaySmall({Color? color}) => GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.lightText,
  );

  // ---------------------------------------------------------------------------
  // Headline Styles (Outfit)
  // ---------------------------------------------------------------------------

  /// Large headline (32px, semi-bold).
  static TextStyle headlineLarge({Color? color}) => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.lightText,
  );

  /// Medium headline (24px, medium).
  static TextStyle headlineMedium({Color? color}) => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.subtleText,
  );

  /// Small headline (20px, medium).
  static TextStyle headlineSmall({Color? color}) => GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.lightText,
  );

  // ---------------------------------------------------------------------------
  // Title Styles (Inter)
  // ---------------------------------------------------------------------------

  /// Large title (20px, semi-bold).
  static TextStyle titleLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.lightText,
  );

  /// Medium title (16px, semi-bold).
  static TextStyle titleMedium({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.lightText,
  );

  /// Small title (14px, semi-bold).
  static TextStyle titleSmall({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.subtleText,
  );

  // ---------------------------------------------------------------------------
  // Body Styles (Inter)
  // ---------------------------------------------------------------------------

  /// Large body text (16px, regular).
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: color ?? AppColors.subtleText,
  );

  /// Medium body text (14px, regular).
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? AppColors.subtleText,
  );

  /// Small body text (12px, regular).
  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.dimText,
  );

  // ---------------------------------------------------------------------------
  // Label Styles (Inter)
  // ---------------------------------------------------------------------------

  /// Large label (14px, semi-bold).
  static TextStyle labelLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.lightText,
  );

  /// Medium label (12px, medium).
  static TextStyle labelMedium({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.subtleText,
  );

  /// Small label (10px, medium).
  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: color ?? AppColors.dimText,
  );

  // ---------------------------------------------------------------------------
  // Tagline Styles (Cormorant Garamond)
  // ---------------------------------------------------------------------------

  /// Tagline text (16px, italic).
  static TextStyle tagline({Color? color}) => GoogleFonts.cormorantGaramond(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: color ?? AppColors.subtleText,
  );

  /// Large tagline text (24px, semi-bold, italic).
  static TextStyle taglineLarge({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: color ?? AppColors.lightText,
      );

  /// Health remark text (36px, bold, italic).
  static TextStyle healthRemark({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: color ?? AppColors.accentRed,
      );

  // ---------------------------------------------------------------------------
  // Score Styles (Outfit)
  // ---------------------------------------------------------------------------

  /// Large score text (80px, bold).
  static TextStyle scoreLarge({Color? color}) => GoogleFonts.outfit(
    fontSize: 80,
    fontWeight: FontWeight.w700,
    height: 1,
    color: color ?? AppColors.accentRed,
  );

  /// Medium score text (52px, bold).
  static TextStyle scoreMedium({Color? color}) => GoogleFonts.outfit(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1,
    color: color ?? AppColors.pureBlack,
  );

  /// Small score text (28px, bold).
  static TextStyle scoreSmall({Color? color}) => GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.lightText,
  );

  // ---------------------------------------------------------------------------
  // App Bar & Navigation
  // ---------------------------------------------------------------------------

  /// App bar title (22px, medium).
  static TextStyle appBarTitle({Color? color, FontWeight? weight}) =>
      GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.lightText,
      );

  /// Navigation label (12px, medium).
  static TextStyle navLabel({Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.dimText,
      );

  // ---------------------------------------------------------------------------
  // Card Styles
  // ---------------------------------------------------------------------------

  /// Card section label (10px, semi-bold, uppercase with letter spacing).
  /// Used for HEALTH, ACTIVITY, PULSE CHECK, DATE, TIME, NOTES etc.
  static TextStyle cardLabel({Color? color}) => GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: color ?? AppColors.warmMuted,
  );

  /// Helper / hint text below card labels (12px, regular).
  static TextStyle helperText({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    color: color ?? AppColors.warmMuted.withValues(alpha: 0.7),
  );
}
