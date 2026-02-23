/// Health score card with animated Voronoi mosaic background.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_checkin.dart';
import '../../../theme/theme.dart';
import '../../../widgets/painters/voronoi_mosaic_painter.dart';

/// Callback type for showing health details.
typedef ShowHealthDetailsCallback = void Function();

/// Animated health score card with Voronoi mosaic background.
///
/// Tiles appear one-by-one with a zoom-in → glow → zoom-out → settle
/// animation. Tile colours represent the health score on a
/// blue (low) → red (high) spectrum.
class HealthCard extends StatefulWidget {
  const HealthCard({
    super.key,
    required this.checkInStats,
    required this.onTap,
  });

  final CheckInStats checkInStats;
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

  /// Health score 0–1 used for colour computation (NOT animation progress).
  double _targetProgress = 0;

  /// Seed for the Voronoi random pattern — changes on each animation start.
  int _seed = DateTime.now().millisecondsSinceEpoch;

  bool _hasAnimated = false;

  /// Tracks how many haptic ticks have fired during tile appearance.
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
    if (oldWidget.checkInStats != widget.checkInStats) {
      _calculateInitialValues();
      if (!_hasAnimated && widget.checkInStats.checkInCount > 0) {
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

  void _calculateInitialValues() {
    final connectionPct = widget.checkInStats.avgConnection * 10;
    final intimacyPct = widget.checkInStats.avgIntimacy * 10;
    final peacePct = widget.checkInStats.avgPeace * 10;
    final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3)
        .round();
    _targetProgress = overallHealth / 100;
  }

  void _onTick() {
    // Haptic feedback while tiles are appearing (0→0.75 of timeline).
    // Fire ~12 evenly spaced ticks during the tile entrance phase.
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

  /// Start the health score animation from the current stats.
  /// Set [forceReanimate] to true to replay the animation (e.g., on refresh).
  void animateHealthScore({bool forceReanimate = false}) {
    if (_hasAnimated && !forceReanimate) return;

    // Fresh seed → fresh Voronoi pattern
    _seed = DateTime.now().millisecondsSinceEpoch;
    _hasAnimated = true;
    _lastHapticTick = -1;

    if (forceReanimate) {
      _controller.reset();
    }

    // Immediate rebuild to show dark state before tiles start appearing
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
    final animProgress = _controller.value;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                const Color(0xFF60A5FA),
                AppColors.accentRed,
                _targetProgress,
              )!.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Layer 1: Voronoi mosaic (full-bleed)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: VoronoiMosaicPainter(
                      animationProgress: animProgress,
                      targetScore: _targetProgress,
                      seed: _seed,
                    ),
                  ),
                ),
              ),

              // Layer 2: Label
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
