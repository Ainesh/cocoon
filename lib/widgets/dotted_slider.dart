/// Score selector with horizontal slider and dotted circle display.
///
/// Layout in a card:
/// [Icon + Label]              [Dotted Circle]
/// [====== THICK Slider ======]    [Score]
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'painters/circle_progress_painters.dart';

/// Low score color (blue).
const _lowColor = Color(0xFF60A5FA);

/// High score color (red).
const _highColor = Color(0xFFE84545);

/// A score selector with:
/// - Card background (like health details sheet)
/// - Stat name aligned with top of circle
/// - Thick horizontal slider with background track
/// - Dotted circle on the right (haptics tied to dot filling)
class ScoreSelector extends StatefulWidget {
  const ScoreSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.icon,
    this.iconAsset,
    this.min = 1.0,
    this.max = 10.0,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final IconData? icon;
  final String? iconAsset;
  final double min;
  final double max;

  @override
  State<ScoreSelector> createState() => _ScoreSelectorState();
}

class _ScoreSelectorState extends State<ScoreSelector> {
  // Circle size matching health card exactly
  static const double circleSize = 100.0;
  
  // Bar height - balanced with circle
  static const double barHeight = 44.0;
  
  // 32 dots like health card - haptics tied to this
  static const int dotCount = 32;
  
  int _lastDotCount = 0;

  double get _progress => (widget.value - widget.min) / (widget.max - widget.min);
  
  /// Interpolate between blue (low) and red (high) based on progress.
  Color get _valueColor => Color.lerp(_lowColor, _highColor, _progress) ?? _highColor;

  @override
  void initState() {
    super.initState();
    _lastDotCount = (dotCount * _progress).round();
  }

  void _handleValueChange(double newValue) {
    final clampedValue = newValue.clamp(widget.min, widget.max);
    final newProgress = (clampedValue - widget.min) / (widget.max - widget.min);
    final newDotCount = (dotCount * newProgress).round();
    
    // Haptic feedback tied to dot filling (like health card)
    if (newDotCount != _lastDotCount) {
      HapticFeedback.selectionClick();
      _lastDotCount = newDotCount;
    }
    
    widget.onChanged(clampedValue);
  }

  @override
  Widget build(BuildContext context) {
    final color = _valueColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Label + slider vertically stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon + Label row
                Row(
                  children: [
                    // Icon container (like health details sheet)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: widget.icon != null
                            ? Icon(widget.icon, color: color, size: 14)
                            : widget.iconAsset != null
                                ? SvgPicture.asset(
                                    widget.iconAsset!,
                                    width: 14,
                                    height: 14,
                                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.warmDim,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Horizontal Slider with visible background track
                _HorizontalSlider(
                  value: widget.value,
                  onChanged: _handleValueChange,
                  min: widget.min,
                  max: widget.max,
                  color: color,
                  height: barHeight,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Right: Dotted Circle with Score
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(circleSize, circleSize),
                  painter: DottedCircleProgressPainter(
                    progress: _progress,
                    activeColor: color,
                    inactiveColor: AppColors.cardVariant,
                    dotCount: dotCount,
                    dotRadius: 2.8,
                  ),
                ),
                Text(
                  widget.value.round().toString(),
                  style: GoogleFonts.outfit(
                    fontSize: circleSize * 0.42,
                    fontWeight: FontWeight.w700,
                    color: color,
                    shadows: [
                      Shadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final newValue = min + progress * (max - min);
    onChanged(newValue);
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
                // BACKGROUND: Subtle empty bar showing full range
                Container(
                  width: trackWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525), // Very subtle, close to card
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                // FOREGROUND: Colored fill with glow (minimum width so it's always visible)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: (trackWidth * progress).clamp(height, trackWidth), // Min width = height (keeps it round)
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
