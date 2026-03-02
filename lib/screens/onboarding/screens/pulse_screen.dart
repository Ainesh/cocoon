/// Screen 3 — Check-in: first check-in during onboarding.
///
/// Title "Check-in" at top. Mosaic card with floating bars appears on prompt
/// tap. After slide-to-check-in: bars hide, congrats message + tap to continue.
library;

import 'dart:math' as math;

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

class PulseScreen extends StatefulWidget {
  const PulseScreen({
    super.key,
    required this.spaceId,
    required this.userName,
    required this.onComplete,
    required this.onSkip,
  });

  final String spaceId;
  final String userName;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // ---------------------------------------------------------------------------
  // State variables
  // ---------------------------------------------------------------------------

  double _titleOp = 0;
  double _subtitleOp = 0;
  double _promptOp = 0;
  double _cardOp = 0;
  double _skipOp = 0;
  double _congratsOp = 0;
  double _continueOp = 0;

  bool _showCard = false;
  bool _hasInteracted = false;
  bool _isSubmitting = false;
  bool _isCompleted = false;

  late List<PulseAttribute> _picks;
  final Map<String, double> _scores = {};
  late final int _mosaicSeed;

  // Controllers
  late final AnimationController _tileController;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  Color _scoreColor(double value) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((value - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  List<Color> get _groupColors =>
      _picks.map((a) => _scoreColor(_scores[a.id] ?? 50)).toList();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _picks = [];
    _mosaicSeed = DateTime.now().millisecondsSinceEpoch;
    _tileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadPicks();
    _runEntrance();
  }

  @override
  void dispose() {
    _tileController.dispose();
    super.dispose();
  }

  Future<void> _loadPicks() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final config = await _firestoreService.getPulseConfig(widget.spaceId);
      final pickIds = config.userPicks[userId] ?? [];
      final picks = pickIds
          .map((id) => PulseAttribute.fromId(id))
          .whereType<PulseAttribute>()
          .toList();
      if (!mounted) return;
      setState(() {
        _picks =
            picks.isEmpty ? PulseAttribute.values.take(3).toList() : picks;
        for (final p in _picks) {
          _scores.putIfAbsent(p.id, () => 50.0);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picks = PulseAttribute.values.take(3).toList();
        for (final p in _picks) {
          _scores.putIfAbsent(p.id, () => 50.0);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Entrance
  // ---------------------------------------------------------------------------

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _titleOp = 1);

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() => _subtitleOp = 1);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _promptOp = 1);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _onPromptTap() {
    if (_showCard) return;
    setState(() {
      _showCard = true;
      _promptOp = 0;
      _subtitleOp = 0;
    });

    _tileController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _cardOp = 1);
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted || _hasInteracted) return;
      setState(() => _skipOp = 1);
    });
  }

  void _onSliderChanged(String id, double value) {
    setState(() {
      _scores[id] = value;
      if (!_hasInteracted) {
        _hasInteracted = true;
        _skipOp = 0;
      }
    });
  }

  Future<void> _submitCheckIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = _authService.currentUser!.uid;
      final intScores = _scores.map((k, v) => MapEntry(k, v.round()));
      final equalWeight = 1.0 / _picks.length;
      final configSnapshot = ConfigSnapshot(
        activeAttributes: _picks.map((p) => p.id).toList(),
        weights: {for (final p in _picks) p.id: equalWeight},
      );

      final checkInId = await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        scores: intScores,
        configSnapshot: configSnapshot,
      );

      final compactScores = <String, dynamic>{};
      for (final p in _picks) {
        compactScores[p.id] = {
          'value': intScores[p.id],
          'weight': equalWeight,
        };
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
      _showPostCheckIn();
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

  Future<void> _showPostCheckIn() async {
    setState(() => _isCompleted = true);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _subtitleOp = 1);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _congratsOp = 1);

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() => _continueOp = 1);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePad = math.max(screenWidth * 0.2, AppSpacing.screenPadding);

    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // --- Title (always at top) ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 800),
                opacity: _titleOp,
                child: Text(
                  'Check-in',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightText,
                    height: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // --- Subtitle ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _subtitleOp,
                child: SizedBox(
                  width: 300,
                  child: Text(
                    'Your space will be alive\nand breathing. Its pulse will\nbe driven by periodic,\nintentional check-ins',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge(
                      color: AppColors.warmDim,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // --- Middle: prompt OR card ---
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: !_showCard
                      ? _buildPrompt()
                      : _buildCardSection(sidePad),
                ),
              ),

              // Bottom spacer for slide-to-action / skip
              SizedBox(height: 80 + bottomPad),
            ],
          ),
        ),

        // --- Slide to check-in (pinned at bottom) ---
        if (_showCard && !_isCompleted)
          Positioned(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            bottom: bottomPad + 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _hasInteracted ? 1.0 : 0.0,
              child: _hasInteracted
                  ? SlideToAction(
                      label: 'Slide to check in',
                      loadingLabel: 'Saving...',
                      onConfirm: _submitCheckIn,
                      isLoading: _isSubmitting,
                    )
                  : const SizedBox.shrink(),
            ),
          ),

        // --- Skip (not recommended) ---
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad + 32,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _skipOp,
            child: GestureDetector(
              onTap: widget.onSkip,
              child: Text(
                'skip (not recommended)',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warmMuted,
                ),
              ),
            ),
          ),
        ),

        // --- Tap to continue (post check-in) ---
        if (_isCompleted)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 32,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _continueOp,
              child: GestureDetector(
                onTap: widget.onComplete,
                child: Text(
                  'tap to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warmDim,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builds
  // ---------------------------------------------------------------------------

  Widget _buildPrompt() {
    return Center(
      key: const ValueKey('prompt'),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _promptOp,
        child: GestureDetector(
          onTap: _onPromptTap,
          child: Text(
            'tap to check-in',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.refinedRed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection(double sidePad) {
    return AnimatedOpacity(
      key: const ValueKey('card'),
      duration: const Duration(milliseconds: 600),
      opacity: _cardOp,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePad),
        child: Column(
          children: [
            // --- Mosaic card ---
            _buildMosaicCard(),

            // --- Bars (hidden after check-in) ---
            if (!_isCompleted) ...[
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _buildBars()),
            ],

            // --- Congrats ---
            if (_isCompleted) ...[
              const SizedBox(height: AppSpacing.xl),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _congratsOp,
                child: Text(
                  'Congrats on your first check-in',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightText,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMosaicCard() {
    if (_picks.isEmpty) return const SizedBox(height: 160);

    return AnimatedBuilder(
      animation: _tileController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: VoronoiGroupedPainter(
                  groupColors: _groupColors,
                  seed: _mosaicSeed,
                  animationProgress: _tileController.value,
                  tileCount: 60,
                  backgroundColor: AppColors.darkCardLight,
                  staggerSpread: 0.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBars() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _picks.length; i++) ...[
          if (i > 0) SizedBox(width: _picks.length <= 3 ? 24 : 12),
          Expanded(
            child: VerticalBarSlider(
              value: _scores[_picks[i].id] ?? 50,
              onChanged: (v) => _onSliderChanged(_picks[i].id, v),
              icon: _picks[i].icon,
              iconAsset: _picks[i].iconAsset,
              label: _picks[i].displayName,
            ),
          ),
        ],
      ],
    );
  }
}
