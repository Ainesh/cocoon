/// Animated tap button with scale and opacity feedback.
///
/// A button wrapper that provides visual feedback (scale + opacity)
/// and haptic feedback when tapped.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button with animated tap feedback.
///
/// Provides:
/// - Scale down animation on press
/// - Opacity reduction on press
/// - Haptic feedback on tap down
///
/// Example:
/// ```dart
/// AnimatedTapButton(
///   onTap: () => print('Tapped!'),
///   child: Container(
///     padding: EdgeInsets.all(16),
///     decoration: BoxDecoration(
///       color: Colors.blue,
///       borderRadius: BorderRadius.circular(12),
///     ),
///     child: Text('Tap Me'),
///   ),
/// )
/// ```
class AnimatedTapButton extends StatefulWidget {
  const AnimatedTapButton({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.scaleAmount = 0.98,
    this.opacityAmount = 0.8,
    this.hapticType = HapticType.light,
  });

  /// The child widget to wrap.
  final Widget child;

  /// Callback when button is tapped.
  final VoidCallback onTap;

  /// Whether the button is enabled (default: true).
  final bool enabled;

  /// Scale amount when pressed (default: 0.98).
  final double scaleAmount;

  /// Opacity when pressed (default: 0.8).
  final double opacityAmount;

  /// Type of haptic feedback (default: light).
  final HapticType hapticType;

  @override
  State<AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

/// Type of haptic feedback.
enum HapticType { light, medium, heavy, selection, none }

class _AnimatedTapButtonState extends State<AnimatedTapButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    _triggerHaptic();
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
  }

  void _triggerHaptic() {
    switch (widget.hapticType) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()
          ..scale(_isPressed ? widget.scaleAmount : 1.0),
        transformAlignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _isPressed ? widget.opacityAmount : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
