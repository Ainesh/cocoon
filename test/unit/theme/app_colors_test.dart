/// Unit tests for AppColors and AppSpacing theme constants.
///
/// Covers: THM-01 through THM-05 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/theme/app_colors.dart';
import 'package:couple_space/theme/app_spacing.dart';

void main() {
  // ===========================================================================
  // AppColors
  // ===========================================================================

  group('AppColors', () {
    // THM-01
    test('constants are non-null and have correct hex values', () {
      expect(AppColors.pureBlack, const Color(0xFF0A0A0A));
      expect(AppColors.darkCardLight, const Color(0xFF1E1E1E));
      expect(AppColors.cardVariant, const Color(0xFF2A2A2A));
      expect(AppColors.accentRed, const Color(0xFFE84545));
      expect(AppColors.accentPurple, const Color(0xFF8A2BE2));
      expect(AppColors.lightText, const Color(0xFFF5F5F5));
      expect(AppColors.warmLight, const Color(0xFFEDE6DB));
      expect(AppColors.warmDim, const Color(0xFF9A938A));
      expect(AppColors.warmMuted, const Color(0xFF6B665F));
      expect(AppColors.success, const Color(0xFF4ADE80));
      expect(AppColors.error, const Color(0xFFFF6B6B));
      expect(AppColors.warning, const Color(0xFFF97316));
      expect(AppColors.morningColor, const Color(0xFF60A5FA));
      expect(AppColors.nightColor, AppColors.accentRed);
    });

    // THM-02
    test('aliases resolve to correct base colors', () {
      // Background aliases
      expect(AppColors.darkSurface, AppColors.darkCardLight);
      expect(AppColors.darkGlass, AppColors.darkCardLight);
      expect(AppColors.darkCard, AppColors.darkCardLight);
      expect(AppColors.cardSurface, AppColors.darkCardLight);

      // Red aliases
      expect(AppColors.refinedRed, AppColors.accentRed);
      expect(AppColors.brightRed, AppColors.accentRed);
      expect(AppColors.deepRed, AppColors.accentRed);

      // Purple alias
      expect(AppColors.softViolet, AppColors.accentPurple);

      // Text aliases
      expect(AppColors.subtleText, AppColors.warmDim);
      expect(AppColors.bodyGray, AppColors.warmLight);
      expect(AppColors.dimText, AppColors.warmMuted);
      expect(AppColors.mutedText, AppColors.warmDim);

      // Semantic aliases
      expect(AppColors.trendNegative, AppColors.error);
    });

    // THM-03
    test('redGlow returns color with correct opacity', () {
      final glow = AppColors.redGlow(0.5);
      expect(glow.a, closeTo(0.5, 0.01));

      final defaultGlow = AppColors.redGlow();
      expect(defaultGlow.a, closeTo(0.15, 0.01));
    });

    test('border returns color with correct opacity', () {
      final border = AppColors.border(0.3);
      expect(border.a, closeTo(0.3, 0.01));

      final defaultBorder = AppColors.border();
      expect(defaultBorder.a, closeTo(0.1, 0.01));
    });
  });

  // ===========================================================================
  // AppSpacing
  // ===========================================================================

  group('AppSpacing', () {
    // THM-04
    test('constants have correct values', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
      expect(AppSpacing.xxxl, 32.0);
      expect(AppSpacing.cardPadding, 16.0);
      expect(AppSpacing.screenPadding, 20.0);
      expect(AppSpacing.cardRadius, 16.0);
    });

    test('spacing values are in ascending order', () {
      expect(AppSpacing.xs < AppSpacing.sm, isTrue);
      expect(AppSpacing.sm < AppSpacing.md, isTrue);
      expect(AppSpacing.md < AppSpacing.lg, isTrue);
      expect(AppSpacing.lg < AppSpacing.xl, isTrue);
      expect(AppSpacing.xl < AppSpacing.xxl, isTrue);
      expect(AppSpacing.xxl < AppSpacing.xxxl, isTrue);
    });

    test('radii are positive', () {
      expect(AppSpacing.radiusSmall, greaterThan(0));
      expect(AppSpacing.radiusMedium, greaterThan(0));
      expect(AppSpacing.cardRadius, greaterThan(0));
      expect(AppSpacing.cardRadiusLarge, greaterThan(0));
      expect(AppSpacing.radiusXL, greaterThan(0));
      expect(AppSpacing.radiusFull, greaterThan(0));
    });

    // THM-05
    test('animation durations are positive', () {
      expect(AppSpacing.durationFast.inMilliseconds, greaterThan(0));
      expect(AppSpacing.durationMedium.inMilliseconds, greaterThan(0));
      expect(AppSpacing.durationSlow.inMilliseconds, greaterThan(0));
      expect(AppSpacing.durationHealthAnimation.inMilliseconds, greaterThan(0));
    });

    test('durations are in ascending order', () {
      expect(AppSpacing.durationFast < AppSpacing.durationMedium, isTrue);
      expect(AppSpacing.durationMedium < AppSpacing.durationSlow, isTrue);
      expect(
        AppSpacing.durationSlow < AppSpacing.durationHealthAnimation,
        isTrue,
      );
    });

    test('icon sizes are positive', () {
      expect(AppSpacing.iconSmall, greaterThan(0));
      expect(AppSpacing.iconMedium, greaterThan(0));
      expect(AppSpacing.iconLarge, greaterThan(0));
      expect(AppSpacing.iconXL, greaterThan(0));
    });

    test('component heights are positive', () {
      expect(AppSpacing.buttonHeight, greaterThan(0));
      expect(AppSpacing.buttonHeightSmall, greaterThan(0));
      expect(AppSpacing.buttonHeightLarge, greaterThan(0));
      expect(AppSpacing.inputHeight, greaterThan(0));
    });
  });
}
