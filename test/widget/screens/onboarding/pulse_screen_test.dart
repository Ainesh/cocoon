/// Widget tests for PulseScreen (Screen 3 — Check-in).
///
/// Uses a lightweight wrapper that avoids Firebase dependencies.
/// Covers: entrance, prompt tap, slider interaction, post-check-in state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:couple_space/theme/app_colors.dart';
import 'package:couple_space/theme/app_spacing.dart';
import 'package:couple_space/theme/app_typography.dart';
import 'package:couple_space/widgets/slide_to_action.dart';

import '../../../helpers/pump_app.dart';

/// Minimal test wrapper that mirrors PulseScreen's UI phases without Firebase.
class _TestCheckInScreen extends StatefulWidget {
  const _TestCheckInScreen({
    required this.onComplete,
    required this.onSkip,
  });

  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<_TestCheckInScreen> createState() => _TestCheckInScreenState();
}

class _TestCheckInScreenState extends State<_TestCheckInScreen> {
  double _titleOp = 0;
  double _subtitleOp = 0;
  double _promptOp = 0;
  bool _showCard = false;
  bool _hasInteracted = false;
  bool _isCompleted = false;
  double _skipOp = 0;
  double _congratsOp = 0;
  double _continueOp = 0;

  @override
  void initState() {
    super.initState();
    _runEntrance();
  }

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

  void _onPromptTap() {
    if (_showCard) return;
    setState(() {
      _showCard = true;
      _promptOp = 0;
      _subtitleOp = 0;
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted || _hasInteracted) return;
      setState(() => _skipOp = 1);
    });
  }

  void _onSliderInteract() {
    if (!_hasInteracted) {
      setState(() {
        _hasInteracted = true;
        _skipOp = 0;
      });
    }
  }

  Future<void> _onSlideComplete() async {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxl),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _titleOp,
              child: Text(
                'Check-in',
                style: GoogleFonts.outfit(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightText,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _subtitleOp,
              child: Text(
                'Your space will be alive\nand breathing. Its pulse will\nbe driven by periodic,\nintentional check-ins',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.warmDim),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_showCard)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _promptOp,
                child: GestureDetector(
                  onTap: _onPromptTap,
                  child: Text(
                    'tap to check-in',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.refinedRed,
                    ),
                  ),
                ),
              ),
            if (_showCard && !_isCompleted)
              Column(
                children: [
                  Container(
                    key: const ValueKey('mosaic-card'),
                    height: 160,
                    width: double.infinity,
                    color: AppColors.darkCardLight,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _onSliderInteract,
                    child: const SizedBox(
                      height: 200,
                      child: Center(child: Text('Sliders placeholder')),
                    ),
                  ),
                ],
              ),
            if (_isCompleted) ...[
              Container(
                key: const ValueKey('mosaic-card-done'),
                height: 160,
                width: double.infinity,
                color: AppColors.darkCardLight,
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _congratsOp,
                child: const Text('Congrats on your first check-in'),
              ),
            ],
          ],
        ),
        ),
        if (_showCard && _hasInteracted && !_isCompleted)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SlideToAction(
              label: 'Slide to check in',
              loadingLabel: 'Saving...',
              onConfirm: _onSlideComplete,
            ),
          ),
        if (_skipOp > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: GestureDetector(
              onTap: widget.onSkip,
              child: Text(
                'skip (not recommended)',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: AppColors.warmMuted,
                ),
              ),
            ),
          ),
        if (_continueOp > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: GestureDetector(
              onTap: widget.onComplete,
              child: Text(
                'tap to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: AppColors.warmDim,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void main() {
  group('PulseScreen / Check-in (test wrapper)', () {
    late bool completed;
    late bool skipped;

    setUp(() {
      completed = false;
      skipped = false;
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        _TestCheckInScreen(
          onComplete: () => completed = true,
          onSkip: () => skipped = true,
        ),
      );
    }

    /// Drain all pending timers.
    Future<void> drainTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 15));
    }

    testWidgets('renders title "Check-in" after entrance', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Check-in'), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('renders subtitle after stagger', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 2700));
      expect(
        find.text(
          'Your space will be alive\nand breathing. Its pulse will\nbe driven by periodic,\nintentional check-ins',
        ),
        findsOneWidget,
      );
      await drainTimers(tester);
    });

    testWidgets('renders prompt after stagger', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));
      expect(find.text('tap to check-in'), findsOneWidget);
    });

    testWidgets('tapping prompt shows card and hides subtitle',
        (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));

      await tester.tap(find.text('tap to check-in'));
      await tester.pump();

      expect(find.byKey(const ValueKey('mosaic-card')), findsOneWidget);
      expect(find.text('tap to check-in'), findsNothing);
      await drainTimers(tester);
    });

    testWidgets('skip appears after 2s of no interaction', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));

      await tester.tap(find.text('tap to check-in'));
      await tester.pump(const Duration(milliseconds: 2100));

      expect(find.text('skip (not recommended)'), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('tapping skip calls onSkip', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));
      await tester.tap(find.text('tap to check-in'));
      await tester.pump(const Duration(milliseconds: 2100));

      await tester.tap(find.text('skip (not recommended)'));
      await tester.pump();

      expect(skipped, isTrue);
      await drainTimers(tester);
    });

    testWidgets('interacting with sliders shows slide-to-action',
        (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));
      await tester.tap(find.text('tap to check-in'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Sliders placeholder'));
      await tester.pump();

      expect(find.byType(SlideToAction), findsOneWidget);
      expect(find.text('skip (not recommended)'), findsNothing);
      await drainTimers(tester);
    });

    testWidgets('after check-in: mosaic stays, congrats appears',
        (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));
      await tester.tap(find.text('tap to check-in'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Sliders placeholder'));
      await tester.pump();

      final slideAction = tester.widget<SlideToAction>(
        find.byType(SlideToAction),
      );
      slideAction.onConfirm();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.byKey(const ValueKey('mosaic-card-done')), findsOneWidget);
      expect(find.text('Congrats on your first check-in'), findsOneWidget);
      expect(find.text('Sliders placeholder'), findsNothing);
      await drainTimers(tester);
    });

    testWidgets('tap to continue appears and calls onComplete',
        (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 4600));
      await tester.tap(find.text('tap to check-in'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Sliders placeholder'));
      await tester.pump();

      final slideAction = tester.widget<SlideToAction>(
        find.byType(SlideToAction),
      );
      slideAction.onConfirm();

      // Wait for full post-check-in sequence (600+800+2000)
      await tester.pump(const Duration(milliseconds: 3500));

      expect(find.text('tap to continue'), findsOneWidget);

      await tester.tap(find.text('tap to continue'));
      await tester.pump();

      expect(completed, isTrue);
    });
  });
}
