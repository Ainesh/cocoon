/// Unified action button with tap animation.
///
/// Used for primary action buttons like "Plan a moment", "Check in",
/// and "Hold to cancel". Provides consistent styling and feedback.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Button layout direction.
enum ActionButtonLayout {
  /// Icon on the right, horizontal layout (default).
  horizontal,

  /// Icon on top, vertical layout for expanded buttons.
  vertical,
}

/// A styled action button with tap animation.
///
/// When pressed:
/// - Background changes to accent color
/// - Text/icon changes to black
/// - Slight scale animation
/// - Haptic feedback
///
/// Example:
/// ```dart
/// ActionButton(
///   label: 'Plan a moment',
///   onTap: () => navigateToMoment(),
/// )
/// ```
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.play_circle_filled_rounded,
    this.showIcon = true,
    this.color,
    this.activeColor,
    this.layout = ActionButtonLayout.horizontal,
    this.expanded = false,
  });

  /// Button label text.
  final String label;

  /// Callback when button is tapped.
  final VoidCallback onTap;

  /// Icon to display (default: play icon).
  final IconData icon;

  /// Whether to show the icon (default: true).
  final bool showIcon;

  /// Custom text/icon color (default: accentRed).
  final Color? color;

  /// Custom background color when active (default: accentRed).
  final Color? activeColor;

  /// Layout direction (default: horizontal).
  final ActionButtonLayout layout;

  /// Whether button should expand to fill available space (default: false).
  final bool expanded;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accentRed;
    final activeColor = widget.activeColor ?? AppColors.accentRed;

    // Colors change based on pressed state
    final bgColor = _isPressed ? activeColor : AppColors.darkCardLight;
    final fgColor = _isPressed ? AppColors.pureBlack : color;

    final content = widget.layout == ActionButtonLayout.vertical
        ? _buildVerticalContent(fgColor)
        : _buildHorizontalContent(fgColor);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: AppSpacing.durationFast,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: widget.layout == ActionButtonLayout.vertical ? 16 : 12,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: content,
      ),
    );
  }

  Widget _buildHorizontalContent(Color fgColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            widget.label,
            style: GoogleFonts.outfit(
              color: fgColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (widget.showIcon)
          Icon(widget.icon, color: fgColor, size: AppSpacing.iconMedium),
      ],
    );
  }

  Widget _buildVerticalContent(Color fgColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.showIcon) ...[
          Icon(widget.icon, color: fgColor, size: AppSpacing.iconMedium),
          const SizedBox(height: 8),
        ],
        Text(
          widget.label,
          style: GoogleFonts.outfit(
            color: fgColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Hold-to-action button variant.
///
/// Requires the user to hold for the action to trigger.
/// Shows visual feedback during hold.
class HoldToActionButton extends StatefulWidget {
  const HoldToActionButton({
    super.key,
    required this.label,
    required this.onHoldComplete,
    this.icon = Icons.chevron_right_rounded,
    this.showIcon = true,
    this.color,
    this.activeColor,
  });

  /// Button label text.
  final String label;

  /// Callback when hold is completed (not started).
  final VoidCallback onHoldComplete;

  /// Icon to display (default: chevron).
  final IconData icon;

  /// Whether to show the icon (default: true).
  final bool showIcon;

  /// Custom text/icon color (default: danger red).
  final Color? color;

  /// Custom background color when active (default: danger red).
  final Color? activeColor;

  @override
  State<HoldToActionButton> createState() => HoldToActionButtonState();
}

class HoldToActionButtonState extends State<HoldToActionButton> {
  bool _isHolding = false;

  /// Whether the button is currently being held.
  bool get isHolding => _isHolding;

  void startHold() {
    setState(() => _isHolding = true);
    HapticFeedback.mediumImpact();
  }

  void cancelHold() {
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    // Use accentRed by default to match ActionButton
    final color = widget.color ?? AppColors.accentRed;
    final activeColor = widget.activeColor ?? AppColors.accentRed;

    // Colors change based on holding state
    final bgColor = _isHolding ? activeColor : AppColors.darkCardLight;
    final fgColor = _isHolding ? AppColors.pureBlack : color;

    return GestureDetector(
      onLongPressStart: (_) => startHold(),
      onLongPressEnd: (_) => cancelHold(),
      onLongPressCancel: cancelHold,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isHolding ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.outfit(
                color: fgColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
