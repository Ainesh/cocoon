/// Health score card with animated progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_checkin.dart';
import '../../../theme/theme.dart';
import '../../../widgets/animations/suspenseful_curve.dart';
import '../../../widgets/painters/circle_progress_painters.dart';

/// Callback type for showing health details.
typedef ShowHealthDetailsCallback = void Function();

/// Animated health score card with dotted progress.
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

class HealthCardState extends State<HealthCard> with SingleTickerProviderStateMixin {
  // Animation constants
  static const int _totalDots = 32;
  static const _suspenseCurve = SuspensefulCurve(steepness: 3.5);

  // Health score animation
  late AnimationController _healthAnimController;
  late Animation<double> _healthAnimation;
  double _targetProgress = 0;
  int _lastHapticDot = -1;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _calculateInitialValues();
  }

  void _calculateInitialValues() {
    // Calculate the target values immediately so we show correct score
    final connectionPct = widget.checkInStats.avgConnection * 10;
    final intimacyPct = widget.checkInStats.avgIntimacy * 10;
    final peacePct = (10 - widget.checkInStats.avgStress) * 10;
    final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3).round();
    _targetProgress = overallHealth / 100;
  }

  void _initAnimations() {
    _healthAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _healthAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _healthAnimController, curve: _suspenseCurve),
    );
    _healthAnimController.addListener(_onHealthAnimationUpdate);
  }

  @override
  void didUpdateWidget(HealthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate if stats changed
    if (oldWidget.checkInStats != widget.checkInStats) {
      _calculateInitialValues();
      // If we haven't animated yet and have real data, trigger animation
      if (!_hasAnimated && widget.checkInStats.checkInCount > 0) {
        animateHealthScore();
      }
    }
  }

  @override
  void dispose() {
    _healthAnimController.removeListener(_onHealthAnimationUpdate);
    _healthAnimController.dispose();
    super.dispose();
  }

  void _onHealthAnimationUpdate() {
    final currentDot = (_healthAnimation.value * _totalDots).floor();
    
    if (currentDot > _lastHapticDot && currentDot <= (_targetProgress * _totalDots).ceil()) {
      _lastHapticDot = currentDot;
      HapticFeedback.lightImpact();
    }
    setState(() {});
  }

  /// Start the health score animation from the current stats.
  /// Set [forceReanimate] to true to replay the animation (e.g., on refresh).
  void animateHealthScore({bool forceReanimate = false}) {
    if (_hasAnimated && !forceReanimate) return; // Only animate once unless forced
    
    // Reset animation state if re-animating
    if (forceReanimate) {
      _healthAnimController.reset();
    }
    
    final connectionPct = widget.checkInStats.avgConnection * 10;
    final intimacyPct = widget.checkInStats.avgIntimacy * 10;
    final peacePct = (10 - widget.checkInStats.avgStress) * 10;
    final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3).round();
    final progress = overallHealth / 100;
    
    _targetProgress = progress;
    _lastHapticDot = -1;
    _hasAnimated = true;
    
    _healthAnimation = Tween<double>(
      begin: 0,
      end: progress,
    ).animate(
      CurvedAnimation(parent: _healthAnimController, curve: _suspenseCurve),
    );
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _healthAnimController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use animated progress if animating, otherwise show static target
    final displayProgress = _hasAnimated ? _healthAnimation.value : _targetProgress;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentRed,
              AppColors.accentRed.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relationship Health',
              style: GoogleFonts.outfit(
                color: AppColors.pureBlack.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            // Score with circular progress
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: DottedCircleProgressPainter(
                        progress: displayProgress,
                        activeColor: AppColors.pureBlack,
                        inactiveColor: AppColors.pureBlack.withValues(alpha: 0.2),
                        dotCount: _totalDots,
                        dotRadius: 3.2,
                      ),
                    ),
                    Text(
                      (displayProgress * 100).round().toString(),
                      style: GoogleFonts.outfit(
                        color: AppColors.pureBlack,
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Individual metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSmallIndicator(Icons.favorite_rounded, widget.checkInStats.avgConnection / 10),
                _buildSmallIndicatorSvg('assets/icons/flame.svg', widget.checkInStats.avgIntimacy / 10),
                _buildSmallIndicatorSvg('assets/icons/peace.svg', (10 - widget.checkInStats.avgStress) / 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallIndicator(IconData icon, double progress) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(44, 44),
            painter: ContinuousCircleProgressPainter(
              progress: progress,
              activeColor: AppColors.pureBlack,
              inactiveColor: AppColors.pureBlack.withValues(alpha: 0.2),
              strokeWidth: 3,
            ),
          ),
          Icon(icon, color: AppColors.pureBlack, size: 18),
        ],
      ),
    );
  }

  Widget _buildSmallIndicatorSvg(String svgPath, double progress) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(44, 44),
            painter: ContinuousCircleProgressPainter(
              progress: progress,
              activeColor: AppColors.pureBlack,
              inactiveColor: AppColors.pureBlack.withValues(alpha: 0.2),
              strokeWidth: 3,
            ),
          ),
          SvgPicture.asset(
            svgPath,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(AppColors.pureBlack, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}
