/// Screen 3 — First Pulse: attribute selection + first check-in combined.
///
/// Phase A: compact attribute chips (pick 3).
/// Phase B: Voronoi mosaic header + vertical bar sliders + SlideToAction.
/// After submit: mosaic celebration overlay.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/pulse_config.dart';
import '../../../scoring/score_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/dotted_slider.dart' show VerticalBarSlider;
import '../../../widgets/painters/voronoi_mosaic_painter.dart';
import '../../../widgets/slide_to_action.dart';

const _attributeDescriptions = <PulseAttribute, String>{
  PulseAttribute.connection: 'Closeness',
  PulseAttribute.intimacy: 'Warmth & passion',
  PulseAttribute.peace: 'Calm & safety',
  PulseAttribute.trust: 'Reliability',
  PulseAttribute.communication: 'Sharing & listening',
};

class FirstPulseScreen extends StatefulWidget {
  const FirstPulseScreen({
    super.key,
    required this.spaceId,
    required this.userName,
    required this.onComplete,
  });

  final String spaceId;
  final String userName;
  final void Function(List<PulseAttribute> picks) onComplete;

  @override
  State<FirstPulseScreen> createState() => _FirstPulseScreenState();
}

class _FirstPulseScreenState extends State<FirstPulseScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Phase A state
  final _selected = <PulseAttribute>{};
  bool _attrsLocked = false;

  // Phase B state
  final Map<String, double> _scores = {};
  bool _isSubmitting = false;
  bool _showCelebration = false;

  // Animation
  late final AnimationController _tileController;
  late final AnimationController _transitionController;
  late final AnimationController _celebrationMosaicController;
  late final int _mosaicSeed;

  @override
  void initState() {
    super.initState();
    _mosaicSeed = DateTime.now().millisecondsSinceEpoch;
    _tileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _celebrationMosaicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _tileController.dispose();
    _transitionController.dispose();
    _celebrationMosaicController.dispose();
    super.dispose();
  }

  bool get _attrsReady => _selected.length == 3;

  List<PulseAttribute> get _picks => _selected.toList();

  Color _scoreColor(double value) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((value - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  double get _averageScore {
    if (_scores.isEmpty) return 0;
    return _scores.values.reduce((a, b) => a + b) / _scores.length / 100;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _toggleAttribute(PulseAttribute attr) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(attr)) {
        _selected.remove(attr);
      } else if (_selected.length < 3) {
        _selected.add(attr);
      }
    });
  }

  void _lockAttributes() {
    if (!_attrsReady) return;
    HapticFeedback.mediumImpact();
    for (final p in _selected) {
      _scores.putIfAbsent(p.id, () => 50.0);
    }
    setState(() => _attrsLocked = true);
    _transitionController.forward();
    _tileController.forward();
  }

  Future<void> _submitCheckIn() async {
    setState(() => _isSubmitting = true);

    try {
      final userId = _authService.currentUser!.uid;
      final picks = _picks;
      final pickIds = picks.map((p) => p.id).toList();

      await _firestoreService.updateUserPicks(
        spaceId: widget.spaceId,
        userId: userId,
        picks: pickIds,
      );

      final intScores = _scores.map((k, v) => MapEntry(k, v.round()));
      final equalWeight = 1.0 / picks.length;
      final configSnapshot = ConfigSnapshot(
        activeAttributes: pickIds,
        weights: {for (final p in picks) p.id: equalWeight},
      );

      final checkInId = await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        scores: intScores,
        configSnapshot: configSnapshot,
      );

      final compactScores = <String, dynamic>{};
      for (final p in picks) {
        compactScores[p.id] = {'value': intScores[p.id], 'weight': equalWeight};
      }

      await _firestoreService.logCheckInActivity(
        spaceId: widget.spaceId,
        userId: userId,
        userName: widget.userName,
        checkInId: checkInId,
        compactScores: compactScores,
      );

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      setState(() => _showCelebration = true);
      _celebrationMosaicController.forward();

      await Future.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      widget.onComplete(picks);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_showCelebration) return _buildCelebration();

    return Container(
      color: AppColors.pureBlack,
      child: SafeArea(
        child: _attrsLocked ? _buildCheckInPhase() : _buildAttributePhase(),
      ),
    );
  }

  // -- Phase A: Attribute selection ---------------------------------------------

  Widget _buildAttributePhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'What matters to you?',
            style: AppTypography.headlineLarge(color: AppColors.lightText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You can only improve what you measure.',
            style: AppTypography.tagline(color: AppColors.warmDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pick 3  ·  ${_selected.length} / 3',
            style: AppTypography.labelMedium(
              color: _attrsReady ? AppColors.refinedRed : AppColors.warmMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Compact chips
          Expanded(
            child: ListView(
              children: PulseAttribute.values.map((attr) {
                final isSelected = _selected.contains(attr);
                final isFaded = _attrsReady && !isSelected;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => _toggleAttribute(attr),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isFaded ? 0.3 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.refinedRed.withValues(alpha: 0.08)
                              : AppColors.darkCardLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.refinedRed.withValues(alpha: 0.5)
                                : AppColors.warmMuted.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            attr.buildIcon(
                              color: isSelected
                                  ? AppColors.refinedRed
                                  : AppColors.warmDim,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attr.displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.refinedRed
                                          : AppColors.lightText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _attributeDescriptions[attr] ?? '',
                                    style: TextStyle(
                                      color: AppColors.warmDim,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedScale(
                              scale: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: AppColors.refinedRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: AppColors.pureBlack,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _attrsReady ? 1.0 : 0.3,
            child: GestureDetector(
              onTap: _attrsReady ? _lockAttributes : null,
              child: Container(
                height: AppSpacing.buttonHeightLarge,
                decoration: BoxDecoration(
                  color: AppColors.refinedRed,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Continue',
                  style: AppTypography.titleMedium(color: AppColors.pureBlack),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // -- Phase B: Check-in ------------------------------------------------------

  Widget _buildCheckInPhase() {
    final picks = _picks;
    final groupColors = picks
        .map((a) => _scoreColor(_scores[a.id] ?? 50))
        .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'Your first pulse',
                    style: AppTypography.headlineLarge(
                      color: AppColors.lightText,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'How are things right now?',
                    style: AppTypography.tagline(color: AppColors.warmDim),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Mosaic + sliders card
                AnimatedBuilder(
                  animation: _tileController,
                  builder: (context, _) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCardLight,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Voronoi mosaic header
                          Stack(
                            children: [
                              RepaintBoundary(
                                child: SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: VoronoiGroupedPainter(
                                      groupColors: groupColors,
                                      seed: _mosaicSeed,
                                      animationProgress: _tileController.value,
                                      tileCount: 50,
                                      backgroundColor: AppColors.darkCardLight,
                                      staggerSpread: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'PULSE CHECK',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                            child: Text(
                              'Slide the bars to express how things feel.',
                              style: AppTypography.helperText(),
                            ),
                          ),

                          // Sliders
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: SizedBox(
                              height: 265,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = 0; i < picks.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 24),
                                    Expanded(
                                      child: VerticalBarSlider(
                                        value: _scores[picks[i].id] ?? 50,
                                        onChanged: (v) => setState(
                                          () => _scores[picks[i].id] = v,
                                        ),
                                        icon: picks[i].icon,
                                        iconAsset: picks[i].iconAsset,
                                        label: picks[i].displayName,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),

        // Slide to action
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SlideToAction(
              label: 'Slide to check in',
              loadingLabel: 'Saving...',
              onConfirm: _submitCheckIn,
              isLoading: _isSubmitting,
            ),
          ),
        ),
      ],
    );
  }

  // -- Celebration overlay ----------------------------------------------------

  Widget _buildCelebration() {
    return Container(
      color: AppColors.pureBlack,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Text(
            'Your mosaic has begun.',
            style: AppTypography.headlineLarge(color: AppColors.lightText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: AnimatedBuilder(
              animation: _celebrationMosaicController,
              builder: (context, _) => CustomPaint(
                size: const Size(280, 180),
                painter: VoronoiMosaicPainter(
                  animationProgress: _celebrationMosaicController.value,
                  targetScore: _averageScore,
                  seed: _mosaicSeed,
                  tileCount: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Every check-in adds a tile.\nEvery tile reveals the picture.',
            textAlign: TextAlign.center,
            style: AppTypography.taglineLarge(color: AppColors.warmDim),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
