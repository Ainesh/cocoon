/// Score selector with horizontal slider.
///
/// Layout:
/// [Icon + Label]
/// [====== THICK Slider ======]
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A score selector with icon, label, and thick horizontal slider.
class ScoreSelector extends StatefulWidget {
  const ScoreSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.icon,
    this.iconAsset,
    this.min = 1.0,
    this.max = 100.0,
    this.embedded = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final IconData? icon;
  final String? iconAsset;
  final double min;
  final double max;

  /// If true, renders without card wrapper (for embedding in a parent card).
  final bool embedded;

  @override
  State<ScoreSelector> createState() => _ScoreSelectorState();
}

class _ScoreSelectorState extends State<ScoreSelector> {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const double _barHeight = 44.0;

  /// Haptic fires every N units (not every 1, too noisy for 1-100).
  static const int _hapticStep = 5;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  int _lastHapticBucket = 0;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  double get _progress =>
      (widget.value - widget.min) / (widget.max - widget.min);

  /// Interpolate between blue (low) and red (high) based on progress.
  Color get _valueColor =>
      Color.lerp(AppColors.morningColor, AppColors.nightColor, _progress) ??
      AppColors.nightColor;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _lastHapticBucket = widget.value.round() ~/ _hapticStep;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _handleValueChange(double newValue) {
    final clamped = newValue.clamp(widget.min, widget.max);
    final bucket = clamped.round() ~/ _hapticStep;

    if (bucket != _lastHapticBucket) {
      HapticFeedback.selectionClick();
      _lastHapticBucket = bucket;
    }

    widget.onChanged(clamped);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final color = _valueColor;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon + Label row
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: widget.icon != null
                    ? Icon(widget.icon, color: color, size: 18)
                    : widget.iconAsset != null
                    ? SvgPicture.asset(
                        widget.iconAsset!,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.warmMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _HorizontalSlider(
          value: widget.value,
          onChanged: _handleValueChange,
          min: widget.min,
          max: widget.max,
          color: color,
          height: _barHeight,
        ),
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}

/// Vertical bar slider with bar, icon + label below.
///
/// Drag vertically to change the value. The bar fills from bottom to top.
/// When [displayProgress] is provided it overrides the computed fill level,
/// allowing an external animation (e.g. fill-from-max entrance).
class VerticalBarSlider extends StatefulWidget {
  const VerticalBarSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.icon,
    this.iconAsset,
    this.min = 1.0,
    this.max = 100.0,
    this.displayProgress,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? label;
  final IconData? icon;
  final String? iconAsset;
  final double min;
  final double max;

  /// When non-null, used as the bar fill level (0–1) instead of computing
  /// from [value]. Enables external entrance animations.
  final double? displayProgress;

  @override
  State<VerticalBarSlider> createState() => _VerticalBarSliderState();
}

class _VerticalBarSliderState extends State<VerticalBarSlider> {
  /// Haptic fires every N units (not every 1, too noisy for 1-100).
  static const int _hapticStep = 5;

  int _lastHapticBucket = 0;

  double get _progress =>
      (widget.value - widget.min) / (widget.max - widget.min);

  Color get _valueColor =>
      Color.lerp(AppColors.morningColor, AppColors.nightColor, _progress) ??
      AppColors.nightColor;

  @override
  void initState() {
    super.initState();
    _lastHapticBucket = widget.value.round() ~/ _hapticStep;
  }

  void _handleDrag(Offset localPosition, double trackHeight) {
    final progress = (1.0 - localPosition.dy / trackHeight).clamp(0.0, 1.0);
    final newValue = (widget.min + progress * (widget.max - widget.min)).clamp(
      widget.min,
      widget.max,
    );
    final bucket = newValue.round() ~/ _hapticStep;

    if (bucket != _lastHapticBucket) {
      HapticFeedback.selectionClick();
      _lastHapticBucket = bucket;
    }

    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final fillProgress = widget.displayProgress ?? _progress;
    final color = _valueColor;
    const borderRadius = 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vertical bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackHeight = constraints.maxHeight;

              return GestureDetector(
                onVerticalDragStart: (d) {
                  HapticFeedback.lightImpact();
                  _handleDrag(d.localPosition, trackHeight);
                },
                onVerticalDragUpdate: (d) =>
                    _handleDrag(d.localPosition, trackHeight),
                onVerticalDragEnd: (_) => HapticFeedback.mediumImpact(),
                onTapDown: (d) {
                  HapticFeedback.lightImpact();
                  _handleDrag(d.localPosition, trackHeight);
                },
                child: SizedBox(
                  width: double.infinity,
                  height: trackHeight,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Background track
                      Container(
                        width: double.infinity,
                        height: trackHeight,
                        decoration: BoxDecoration(
                          color: AppColors.cardVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      // Filled bar (bottom-up)
                      AnimatedContainer(
                        duration: Duration(
                          milliseconds: widget.displayProgress != null ? 0 : 50,
                        ),
                        width: double.infinity,
                        height: (trackHeight * fillProgress).clamp(
                          trackHeight * 0.05,
                          trackHeight,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(borderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Icon below bar
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: color, size: 18)
                : widget.iconAsset != null
                ? SvgPicture.asset(
                    widget.iconAsset!,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  )
                : null,
          ),
        ),

        // Label below icon
        if (widget.label != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.warmMuted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontal slider with background track to show range.
class _HorizontalSlider extends StatelessWidget {
  const _HorizontalSlider({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.color,
    required this.height,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color color;
  final double height;

  void _handleDrag(Offset localPosition, double trackWidth) {
    final progress = (localPosition.dx / trackWidth).clamp(0.0, 1.0);
    onChanged(min + progress * (max - min));
  }

  @override
  Widget build(BuildContext context) {
    final progress = (value - min) / (max - min);
    const borderRadius = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            HapticFeedback.lightImpact();
            _handleDrag(details.localPosition, trackWidth);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition, trackWidth);
          },
          onHorizontalDragEnd: (_) => HapticFeedback.mediumImpact(),
          onTapDown: (details) {
            HapticFeedback.lightImpact();
            _handleDrag(details.localPosition, trackWidth);
          },
          child: SizedBox(
            width: trackWidth,
            height: height,
            child: Stack(
              children: [
                // Background track
                Container(
                  width: trackWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.cardVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                // Filled track
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: (trackWidth * progress).clamp(
                    trackWidth * 0.05,
                    trackWidth,
                  ),
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
