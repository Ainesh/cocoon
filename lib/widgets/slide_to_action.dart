/// Slide-to-confirm action button.
///
/// A swipeable button that requires the user to slide all the way
/// to confirm an action. Provides visual feedback and haptics.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A slide-to-confirm button for important actions.
///
/// The user must swipe the bar all the way to the right to trigger
/// the [onConfirm] callback. Includes haptic feedback and smooth
/// animations.
///
/// Example:
/// ```dart
/// SlideToAction(
///   label: 'Slide to confirm',
///   loadingLabel: 'Processing...',
///   onConfirm: () => doSomething(),
///   isLoading: false,
/// )
/// ```
class SlideToAction extends StatefulWidget {
  const SlideToAction({
    super.key,
    required this.onConfirm,
    this.label = 'Slide to confirm',
    this.loadingLabel = 'Processing...',
    this.isLoading = false,
    this.enabled = true,
    this.height = 52.0,
    this.borderRadius = 12.0,
    this.minBarWidth = 160.0,
    this.barColor,
    this.disabledBarColor,
    this.trackColor,
  });

  /// Callback when slide is completed
  final VoidCallback onConfirm;

  /// Label shown on the bar (default: 'Slide to confirm')
  final String label;

  /// Label shown while loading (default: 'Processing...')
  final String loadingLabel;

  /// Whether the action is in progress
  final bool isLoading;

  /// Whether the slider is enabled (default: true)
  /// When disabled, slider is grayed out and non-interactive
  final bool enabled;

  /// Height of the slider (default: 52)
  final double height;

  /// Corner radius (default: 12)
  final double borderRadius;

  /// Minimum width of the draggable bar (default: 160)
  final double minBarWidth;

  /// Color of the draggable bar (default: accentRed)
  final Color? barColor;

  /// Color of the bar when disabled (default: warmMuted)
  final Color? disabledBarColor;

  /// Color of the background track (default: cardVariant at 50%)
  final Color? trackColor;

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction> {
  double _dragPosition = 0;
  bool _isDragging = false;

  static const double _targetIconSize = 32.0;
  static const double _targetPadding = 10.0;

  void _onDragStart(DragStartDetails details) {
    if (widget.isLoading || !widget.enabled) return;
    setState(() => _isDragging = true);
    HapticFeedback.lightImpact();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (widget.isLoading || !widget.enabled) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (widget.isLoading || !widget.enabled) return;

    // Check if reached the target (within 95% of max - swipe all the way)
    if (_dragPosition >= maxDrag * 0.95) {
      HapticFeedback.heavyImpact();
      widget.onConfirm();
      // Keep at end while loading
      setState(() {
        _dragPosition = maxDrag;
        _isDragging = false;
      });
    } else {
      // Snap back
      HapticFeedback.mediumImpact();
      setState(() {
        _dragPosition = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBarColor = widget.barColor ?? AppColors.accentRed;
    final disabledBarColor = widget.disabledBarColor ?? AppColors.warmMuted;
    final barColor = widget.enabled ? activeBarColor : disabledBarColor;
    final trackColor =
        widget.trackColor ?? AppColors.cardVariant.withValues(alpha: 0.5);
    final textColor = widget.enabled ? AppColors.pureBlack : AppColors.warmDim;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        // Bar slides all the way to the right edge (covers play button)
        final maxDrag = trackWidth - widget.minBarWidth;
        final barWidth = widget.minBarWidth + _dragPosition;
        final progress = maxDrag > 0 ? _dragPosition / maxDrag : 0.0;

        return SizedBox(
          width: trackWidth,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // BACKGROUND: Subtle empty capsule showing full range
              Container(
                width: trackWidth,
                height: widget.height,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),

              // Target play icon at the far right (behind the bar)
              Positioned(
                right: _targetPadding,
                top: (widget.height - _targetIconSize) / 2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: progress > 0.8 ? 0.0 : (widget.enabled ? 1.0 : 0.4),
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    color: barColor,
                    size: _targetIconSize,
                  ),
                ),
              ),

              // FOREGROUND: Draggable bar with glow - slides over the play button
              GestureDetector(
                onHorizontalDragStart: widget.enabled ? _onDragStart : null,
                onHorizontalDragUpdate: widget.enabled
                    ? (d) => _onDragUpdate(d, maxDrag)
                    : null,
                onHorizontalDragEnd: widget.enabled
                    ? (d) => _onDragEnd(d, maxDrag)
                    : null,
                child: AnimatedContainer(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  width: barWidth,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: widget.enabled
                        ? [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null, // No glow when disabled
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: textColor,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.loadingLabel,
                                style: GoogleFonts.outfit(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 100),
                            opacity: _isDragging
                                ? 0.0
                                : 1.0, // Hide text while dragging
                            child: Text(
                              widget.label,
                              style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
