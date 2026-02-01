/// Glass container widget for futuristic UI effects.
///
/// Creates a frosted glass effect with backdrop blur and subtle borders.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

/// A container with a frosted glass effect.
///
/// Uses backdrop blur and semi-transparent backgrounds to create
/// a modern, futuristic glass morphism effect.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderOpacity = 0.2,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  /// The widget to display inside the glass container.
  final Widget child;

  /// The border radius of the container.
  final double borderRadius;

  /// The blur intensity for the backdrop filter.
  final double blur;

  /// The opacity of the background fill (0.0 - 1.0).
  final double opacity;

  /// The opacity of the border (0.0 - 1.0).
  final double borderOpacity;

  /// Padding inside the container.
  final EdgeInsetsGeometry? padding;

  /// Margin around the container.
  final EdgeInsetsGeometry? margin;

  /// Fixed width of the container.
  final double? width;

  /// Fixed height of the container.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: borderOpacity),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A card with glass morphism effect.
///
/// Convenience widget that wraps [GlassContainer] with card-like defaults.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      opacity: 0.15,
      borderOpacity: 0.3,
      child: child,
    );
  }
}
