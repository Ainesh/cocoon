/// Health score card with animated Voronoi mosaic background.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../scoring/score_models.dart';
import '../../../theme/theme.dart';
import '../../../widgets/painters/voronoi_mosaic_painter.dart';

/// Callback type for showing health details.
typedef ShowHealthDetailsCallback = void Function();

/// Animated health score card with Voronoi mosaic background.
///
/// Mosaic stays grayed out until both users have checked in at least once.
class HealthCard extends StatefulWidget {
  const HealthCard({
    super.key,
    required this.scoreResult,
    required this.onTap,
  });

  final ScoreResult scoreResult;
  final ShowHealthDetailsCallback onTap;

  @override
  State<HealthCard> createState() => HealthCardState();
}

class HealthCardState extends State<HealthCard>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  late AnimationController _controller;

  double _targetProgress = 0;
  int _seed = DateTime.now().millisecondsSinceEpoch;
  bool _hasAnimated = false;
  int _lastHapticTick = -1;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _controller.addListener(_onTick);
    _controller.addStatusListener(_onStatus);
    _calculateInitialValues();
  }

  @override
  void didUpdateWidget(HealthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scoreResult.overallScore !=
        widget.scoreResult.overallScore) {
      _calculateInitialValues();
      if (!_hasAnimated && _hasBothCheckedIn) {
        animateHealthScore();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _hasBothCheckedIn =>
      widget.scoreResult.userCheckInCount > 0 &&
      widget.scoreResult.partnerCheckInCount > 0;

  void _calculateInitialValues() {
    _targetProgress = _hasBothCheckedIn
        ? widget.scoreResult.overallScore / 100
        : 0;
  }

  void _onTick() {
    final progress = _controller.value;
    if (progress <= 0.75) {
      const totalTicks = 12;
      final tick = (progress / 0.75 * totalTicks).floor();
      if (tick > _lastHapticTick) {
        _lastHapticTick = tick;
        HapticFeedback.lightImpact();
      }
    }
    if (mounted) setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.lightImpact();
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void animateHealthScore({bool forceReanimate = false}) {
    if (!_hasBothCheckedIn) return;
    if (_hasAnimated && !forceReanimate) return;

    _seed = DateTime.now().millisecondsSinceEpoch;
    _hasAnimated = true;
    _lastHapticTick = -1;

    if (forceReanimate) {
      _controller.reset();
    }

    setState(() {});

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _controller.forward(from: 0);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final animProgress = _hasBothCheckedIn ? _controller.value : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hasBothCheckedIn
              ? [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0xFF60A5FA),
                      AppColors.accentRed,
                      _targetProgress,
                    )!.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Mosaic — gray tiles when not enough data, coloured when active
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: VoronoiMosaicPainter(
                      animationProgress:
                          _hasBothCheckedIn ? animProgress : 1.0,
                      targetScore: _hasBothCheckedIn ? _targetProgress : 0.5,
                      seed: _seed,
                      coolColor: _hasBothCheckedIn
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF3A3A3A),
                      warmColor: _hasBothCheckedIn
                          ? const Color(0xFFE84545)
                          : const Color(0xFF4A4A4A),
                    ),
                  ),
                ),
              ),
              // Label
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'HEALTH',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
