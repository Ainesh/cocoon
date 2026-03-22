/// Configuration model for the Spectral Aura avatar system.
///
/// Defines colors, intensity, and optional particle count for the
/// animated radial glow that represents a user's identity.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Preset aura color palettes.
enum AuraPreset {
  ember(AppColors.accentRed, Color(0xFFFF8A65), 'Ember'),
  ocean(AppColors.morningColor, Color(0xFF81D4FA), 'Ocean'),
  violet(AppColors.accentPurple, Color(0xFFCE93D8), 'Violet'),
  amber(Color(0xFFF59E0B), Color(0xFFFFD54F), 'Amber');

  const AuraPreset(this.primaryColor, this.secondaryColor, this.label);

  final Color primaryColor;
  final Color secondaryColor;
  final String label;

  /// Pick a default preset from a name hash.
  static AuraPreset fromName(String name) {
    if (name.isEmpty) return ember;
    return values[name.hashCode.abs() % values.length];
  }
}

/// Immutable configuration for a [SpectralAura] widget.
@immutable
class AuraConfig {
  const AuraConfig({
    required this.primaryColor,
    required this.secondaryColor,
    this.intensity = 0.7,
    this.particleCount = 0,
  });

  final Color primaryColor;
  final Color secondaryColor;

  /// Overall glow brightness / scale factor (0.0 - 1.0).
  final double intensity;

  /// Number of orbiting particles. 0 = none (clean for onboarding).
  final int particleCount;

  /// Create from a preset palette.
  factory AuraConfig.fromPreset(AuraPreset preset, {double intensity = 0.7}) {
    return AuraConfig(
      primaryColor: preset.primaryColor,
      secondaryColor: preset.secondaryColor,
      intensity: intensity,
    );
  }

  /// Create from check-in statistics (for dashboard use later).
  factory AuraConfig.fromCheckInStats({
    required double overallScore,
    required int checkInCount,
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    final intensity = (overallScore / 100).clamp(0.3, 1.0);
    final particles = checkInCount > 10 ? (checkInCount ~/ 5).clamp(0, 8) : 0;
    return AuraConfig(
      primaryColor: primaryColor ?? AppColors.accentRed,
      secondaryColor: secondaryColor ?? const Color(0xFFFF8A65),
      intensity: intensity,
      particleCount: particles,
    );
  }
}
