/// Centralized color definitions for Cocoon app.
///
/// Use these constants throughout the app to maintain consistency.
/// Import: `import 'package:couple_space/theme/app_colors.dart';`
library;

import 'package:flutter/material.dart';

/// Cocoon app color palette - Dark neumorphic theme with warm red accent.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------------------------
  
  /// Screen / sheet background (#0A0A0A).
  static const pureBlack = Color(0xFF0A0A0A);
  
  /// Standard card background (#1E1E1E).
  static const darkCardLight = Color(0xFF1E1E1E);
  
  /// Nested elements inside cards (#2A2A2A).
  static const cardVariant = Color(0xFF2A2A2A);

  /// Aliases — all resolve to one of the above for backward compatibility.
  static const darkSurface = darkCardLight;
  static const darkGlass = darkCardLight;
  static const darkCard = darkCardLight;
  static const cardSurface = darkCardLight;

  // ---------------------------------------------------------------------------
  // Primary Red
  // ---------------------------------------------------------------------------
  
  /// The single primary red used throughout the app (#E84545).
  static const accentRed = Color(0xFFE84545);

  /// Aliases — all resolve to [accentRed] for backward compatibility.
  static const refinedRed = accentRed;
  static const brightRed = accentRed;
  static const deepRed = accentRed;

  // ---------------------------------------------------------------------------
  // Secondary Purple
  // ---------------------------------------------------------------------------
  
  /// Secondary accent purple (#8A2BE2).
  static const accentPurple = Color(0xFF8A2BE2);

  /// Alias.
  static const softViolet = accentPurple;

  // ---------------------------------------------------------------------------
  // Text Colors
  // ---------------------------------------------------------------------------
  
  /// Primary text on dark backgrounds (#F5F5F5).
  static const lightText = Color(0xFFF5F5F5);

  /// High-contrast warm text (#EDE6DB).
  static const warmLight = Color(0xFFEDE6DB);
  
  /// Secondary / body text (#9A938A).
  static const warmDim = Color(0xFF9A938A);
  
  /// Tertiary / label text (#6B665F).
  static const warmMuted = Color(0xFF6B665F);

  /// Aliases — resolve to the warm text scale for backward compatibility.
  static const subtleText = warmDim;
  static const bodyGray = warmLight;
  static const dimText = warmMuted;
  static const mutedText = warmDim;

  // ---------------------------------------------------------------------------
  // Semantic Colors
  // ---------------------------------------------------------------------------
  
  /// Success / positive (#4ADE80).
  static const success = Color(0xFF4ADE80);
  
  /// Error / negative (#FF6B6B).
  static const error = Color(0xFFFF6B6B);
  
  /// Warning (#F97316).
  static const warning = Color(0xFFF97316);

  /// Alias — trend negative uses error colour.
  static const trendNegative = error;

  // ---------------------------------------------------------------------------
  // Time Slot Colors (for sliders and gradients)
  // ---------------------------------------------------------------------------
  
  /// Morning/low value color - Cool blue (#60A5FA)
  static const morningColor = Color(0xFF60A5FA);
  
  /// Night/high value color - Warm red (same as accentRed)
  static const nightColor = accentRed;

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------
  
  /// Returns a red glow color with specified opacity.
  static Color redGlow([double opacity = 0.15]) => 
      refinedRed.withValues(alpha: opacity);
  
  /// Returns a border color with specified opacity.
  static Color border([double opacity = 0.1]) => 
      refinedRed.withValues(alpha: opacity);
}
