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
  
  /// Pure black background (#0A0A0A)
  static const pureBlack = Color(0xFF0A0A0A);
  
  /// Dark surface for elevated elements (#121212)
  static const darkSurface = Color(0xFF121212);
  
  /// Dark glass for cards and containers (#1A1A1A)
  static const darkGlass = Color(0xFF1A1A1A);
  
  /// Card background (#161616)
  static const darkCard = Color(0xFF161616);
  
  /// Lighter card background for contrast (#1E1E1E)
  static const darkCardLight = Color(0xFF1E1E1E);
  
  /// Card variant for nested elements (#2A2A2A)
  static const cardVariant = Color(0xFF2A2A2A);
  
  /// Card surface for Material theming (#242424)
  static const cardSurface = Color(0xFF242424);

  // ---------------------------------------------------------------------------
  // Primary - Refined Red
  // ---------------------------------------------------------------------------
  
  /// Primary accent red (#FF4444)
  static const refinedRed = Color(0xFFFF4444);
  
  /// Brighter red variant (#FF5555)
  static const brightRed = Color(0xFFFF5555);
  
  /// Deeper red variant (#E63939)
  static const deepRed = Color(0xFFE63939);
  
  /// Dashboard accent red (#E84545)
  static const accentRed = Color(0xFFE84545);

  // ---------------------------------------------------------------------------
  // Secondary - Purple Accent
  // ---------------------------------------------------------------------------
  
  /// Secondary purple accent (#8A2BE2)
  static const accentPurple = Color(0xFF8A2BE2);
  
  /// Soft violet variant (#A855F7)
  static const softViolet = Color(0xFFA855F7);

  // ---------------------------------------------------------------------------
  // Text Colors
  // ---------------------------------------------------------------------------
  
  /// Light text on dark backgrounds (#F5F5F5)
  static const lightText = Color(0xFFF5F5F5);
  
  /// Subtle/secondary text (#B8B8B8)
  static const subtleText = Color(0xFFB8B8B8);
  
  /// Dim text for less emphasis (#707070)
  static const dimText = Color(0xFF707070);
  
  /// Body text gray (#D1D5DB)
  static const bodyGray = Color(0xFFD1D5DB);
  
  /// Muted text (#9CA3AF)
  static const mutedText = Color(0xFF9CA3AF);

  // ---------------------------------------------------------------------------
  // Warm Tones (Dashboard specific)
  // ---------------------------------------------------------------------------
  
  /// Warm cream for high-contrast text (#EDE6DB)
  static const warmLight = Color(0xFFEDE6DB);
  
  /// Warm dim gray (#9A938A)
  static const warmDim = Color(0xFF9A938A);
  
  /// Warm muted gray (#6B665F)
  static const warmMuted = Color(0xFF6B665F);

  // ---------------------------------------------------------------------------
  // Semantic Colors
  // ---------------------------------------------------------------------------
  
  /// Success/positive green (#4ADE80)
  static const success = Color(0xFF4ADE80);
  
  /// Error/negative red (#FF6B6B)
  static const error = Color(0xFFFF6B6B);
  
  /// Warning orange (#F97316)
  static const warning = Color(0xFFF97316);

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
