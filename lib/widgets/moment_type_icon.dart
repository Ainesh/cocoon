/// Shared moment type icon widget.
///
/// Provides consistent icon rendering for moment types across the app.
/// Connect uses a custom SVG, while Celebrate and Escape use Material icons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/moment.dart';
import '../theme/app_colors.dart';

/// Returns the Material icon for a moment type.
/// For Connect, use [getMomentTypeIconWidget] instead to get the SVG.
IconData getMomentTypeIcon(MomentType type) {
  return switch (type) {
    MomentType.celebrate => Icons.auto_awesome_rounded,
    MomentType.connect => Icons.power_rounded, // Fallback for non-SVG contexts
    MomentType.escape => Icons.flight_rounded,
  };
}

/// Returns the appropriate icon widget for a moment type.
///
/// Connect uses a custom SVG from `assets/icons/connect.svg`.
/// Celebrate and Escape use Material icons.
///
/// Example:
/// ```dart
/// getMomentTypeIconWidget(MomentType.connect, size: 24, color: AppColors.accentRed)
/// ```
Widget getMomentTypeIconWidget(
  MomentType type, {
  double size = 16,
  Color? color,
}) {
  final iconColor = color ?? AppColors.accentRed;

  if (type == MomentType.connect) {
    return SvgPicture.asset(
      'assets/icons/connect.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }

  return Icon(
    getMomentTypeIcon(type),
    size: size,
    color: iconColor,
  );
}
