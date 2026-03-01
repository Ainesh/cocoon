/// Parent orchestrator for the onboarding experience.
///
/// Owns the breathing Voronoi mosaic as a persistent full-screen background.
/// Individual screens are transparent content overlays that crossfade on top.
///
/// Screen 0: Kairos splash (text overlay, full mosaic with radial gradient)
/// Screen 1: Your Space (space name — mosaic in bands mode)
/// Screen 2: About You (name + avatar + space creation)
/// Screen 3: First Pulse (facets + check-in combined)
/// Screen 4: Almost There (invite + notifications)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../widgets/painters/voronoi_mosaic_painter.dart';
import 'screens/about_you_screen.dart';
import 'screens/complete_screen.dart';
import 'screens/first_pulse_screen.dart';
import 'screens/the_word_screen.dart';
import 'screens/your_space_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Mosaic animation
  // ---------------------------------------------------------------------------

  late final AnimationController _entranceController;
  late final AnimationController _breathController;
  late final AnimationController _fillController;
  late final AnimationController _bandsController;
  late final int _mosaicSeed;
  bool _splashTapped = false;
  int _breathHapticHalf = -1;
  int _fillHapticTick = -1;
  int _bandsHapticTick = -1;

  // ---------------------------------------------------------------------------
  // Screen management
  // ---------------------------------------------------------------------------

  int _currentScreen = 0;

  // ---------------------------------------------------------------------------
  // Shared state
  // ---------------------------------------------------------------------------

  String _spaceName = 'Us ❤️';
  String? _spaceId;
  String? _inviteCode;
  String _userName = '';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _mosaicSeed = DateTime.now().millisecondsSinceEpoch;

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )
      ..addListener(_onBreathTick)
      ..repeat();

    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )
      ..addListener(_onFillTick)
      ..addStatusListener(_onFillDone);

    _bandsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(_onBandsTick);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathController.dispose();
    _fillController.dispose();
    _bandsController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Haptics — synced to tile activity
  // ---------------------------------------------------------------------------

  void _onBreathTick() {
    // Gentle pulse once per breath cycle (every 4s). Fire at the halfway
    // mark so the haptic lands near the sine-wave peak.
    final half = (_breathController.value * 2).floor();
    if (half != _breathHapticHalf) {
      _breathHapticHalf = half;
      // Only pulse during idle states (not during fill/bands transitions)
      if (_fillController.value == 0 ||
          (_fillController.value == 1 && _bandsController.value == 1)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onFillTick() {
    // Intensifying: 8 ticks on a quadratic curve (bunch up toward the end).
    final p = _fillController.value;
    final tick = (p * p * 8).floor();
    if (tick > _fillHapticTick) {
      _fillHapticTick = tick;
      if (tick < 3) {
        HapticFeedback.lightImpact();
      } else if (tick < 6) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _onBandsTick() {
    // Simmering down: 5 ticks on an inverse curve (spread out toward end).
    final p = _bandsController.value;
    final tick = (math.sqrt(p) * 5).floor();
    if (tick > _bandsHapticTick) {
      _bandsHapticTick = tick;
      if (tick == 0) {
        HapticFeedback.heavyImpact();
      } else if (tick < 3) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Splash → screen 1 transition
  // ---------------------------------------------------------------------------

  void _onSplashTap() {
    if (_splashTapped) return;
    _splashTapped = true;
    HapticFeedback.mediumImpact();
    _fillController.forward();
  }

  void _onFillDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _bandsController.forward();
      setState(() => _currentScreen = 1);
    });
  }

  // ---------------------------------------------------------------------------
  // Screen navigation
  // ---------------------------------------------------------------------------

  void _goTo(int screen) => setState(() => _currentScreen = screen);

  void _finish() {
    if (_spaceId != null) {
      context.go('/dashboard/$_spaceId');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _breathController,
          _fillController,
          _bandsController,
        ]),
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: VoronoiBreathingPainter(
                  breathPhase: _breathController.value,
                  entranceProgress: _entranceController.value,
                  fillProgress: _fillController.value,
                  bandsProgress: _bandsController.value,
                  exclusionRadius: 0.12,
                  targetScore: 0.85,
                  seed: _mosaicSeed,
                  tileCount: 120,
                ),
              ),
            ),
            child!,
          ],
        ),
        child: _buildScreenStack(),
      ),
    );
  }

  Widget _buildScreenStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Screen 0 — splash text overlay
        if (_currentScreen == 0)
          TheWordScreen(onTap: _onSplashTap),

        // Screen 1 — space name
        if (_currentScreen >= 1)
          _ScreenLayer(
            isActive: _currentScreen == 1,
            child: YourSpaceScreen(
              initialName: _spaceName,
              onContinue: (name) {
                _spaceName = name;
                _goTo(2);
              },
            ),
          ),

        // Screen 2 — about you
        if (_currentScreen >= 2)
          _ScreenLayer(
            isActive: _currentScreen == 2,
            child: AboutYouScreen(
              spaceName: _spaceName,
              onSpaceCreated: (spaceId, inviteCode, userName) {
                _spaceId = spaceId;
                _inviteCode = inviteCode;
                _userName = userName;
                _goTo(3);
              },
            ),
          ),

        // Screen 3 — facets + check-in
        if (_currentScreen >= 3)
          _ScreenLayer(
            isActive: _currentScreen == 3,
            child: FirstPulseScreen(
              spaceId: _spaceId ?? '',
              userName: _userName,
              onComplete: (_) => _goTo(4),
            ),
          ),

        // Screen 4 — invite + notifications
        if (_currentScreen >= 4)
          CompleteScreen(
            inviteCode: _inviteCode ?? '',
            onFinish: _finish,
          ),

      ],
    );
  }
}

/// Fades in screen content after a delay, allowing the mosaic tile-clearing
/// animation to open up space in the center first.
class _ScreenLayer extends StatefulWidget {
  const _ScreenLayer({required this.isActive, required this.child});

  final bool isActive;
  final Widget child;

  @override
  State<_ScreenLayer> createState() => _ScreenLayerState();
}

class _ScreenLayerState extends State<_ScreenLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isActive) _controller.forward();
  }

  @override
  void didUpdateWidget(_ScreenLayer old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _controller.forward();
    } else if (!widget.isActive && old.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isActive,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Content fades in after tiles have cleared the center
          final fadeT = Curves.easeOut.transform(
            const Interval(0.55, 0.85).transform(_controller.value),
          );
          return Opacity(opacity: fadeT, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
