/// Design spacing and sizing constants.
///
/// Provides consistent spacing values throughout the app to ensure
/// visual harmony and maintainability.
///
/// Usage:
/// ```dart
/// import 'package:couple_space/theme/app_spacing.dart';
///
/// SizedBox(height: AppSpacing.md);
/// EdgeInsets.all(AppSpacing.cardPadding);
/// BorderRadius.circular(AppSpacing.cardRadius);
/// ```
library;

/// Spacing constants for consistent layouts.
abstract final class AppSpacing {
  // ---------------------------------------------------------------------------
  // Base Spacing Scale (4px increments)
  // ---------------------------------------------------------------------------

  /// 4px - Minimal spacing
  static const double xs = 4.0;

  /// 8px - Tight spacing
  static const double sm = 8.0;

  /// 12px - Compact spacing
  static const double md = 12.0;

  /// 16px - Default spacing
  static const double lg = 16.0;

  /// 20px - Comfortable spacing
  static const double xl = 20.0;

  /// 24px - Generous spacing
  static const double xxl = 24.0;

  /// 32px - Section spacing
  static const double xxxl = 32.0;

  // ---------------------------------------------------------------------------
  // Component-Specific Spacing
  // ---------------------------------------------------------------------------

  /// Default card internal padding
  static const double cardPadding = 16.0;

  /// Premium card internal padding
  static const double cardPaddingLarge = 20.0;

  /// Space between cards in lists
  static const double cardGap = 16.0;

  /// Screen edge padding
  static const double screenPadding = 20.0;

  /// Bottom sheet padding
  static const double sheetPadding = 24.0;

  /// Form field spacing
  static const double fieldGap = 16.0;

  /// Section divider spacing
  static const double sectionGap = 24.0;

  // ---------------------------------------------------------------------------
  // Border Radii
  // ---------------------------------------------------------------------------

  /// Small radius for buttons, inputs
  static const double radiusSmall = 8.0;

  /// Medium radius for smaller cards
  static const double radiusMedium = 12.0;

  /// Default card radius
  static const double cardRadius = 16.0;

  /// Large card radius
  static const double cardRadiusLarge = 20.0;

  /// Extra large radius for modals
  static const double radiusXL = 24.0;

  /// Full radius for pills/capsules
  static const double radiusFull = 9999.0;

  // ---------------------------------------------------------------------------
  // Icon Sizes
  // ---------------------------------------------------------------------------

  /// Small icons in labels
  static const double iconSmall = 16.0;

  /// Default icon size
  static const double iconMedium = 20.0;

  /// Large icons in buttons
  static const double iconLarge = 24.0;

  /// Icons in empty states
  static const double iconXL = 48.0;

  // ---------------------------------------------------------------------------
  // Component Heights
  // ---------------------------------------------------------------------------

  /// Standard button height
  static const double buttonHeight = 48.0;

  /// Compact button height
  static const double buttonHeightSmall = 40.0;

  /// Large action button height
  static const double buttonHeightLarge = 52.0;

  /// Input field height
  static const double inputHeight = 48.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Bottom nav bar height
  static const double bottomNavHeight = 80.0;

  // ---------------------------------------------------------------------------
  // Health Card Specific
  // ---------------------------------------------------------------------------

  /// Main health score circle size
  static const double healthCircleSize = 120.0;

  /// Small metric indicator size
  static const double metricIndicatorSize = 44.0;

  /// Health card dot count
  static const int healthDotCount = 32;

  /// Health card dot radius
  static const double healthDotRadius = 3.2;

  // ---------------------------------------------------------------------------
  // Animation Durations
  // ---------------------------------------------------------------------------

  /// Fast micro-interactions
  static const Duration durationFast = Duration(milliseconds: 100);

  /// Standard transitions
  static const Duration durationMedium = Duration(milliseconds: 200);

  /// Slow, deliberate animations
  static const Duration durationSlow = Duration(milliseconds: 400);

  /// Health score animation
  static const Duration durationHealthAnimation = Duration(milliseconds: 2200);
}
