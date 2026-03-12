/// Spectral Aura — animated orb avatar placeholder.
///
/// Currently uses a CustomPainter fallback while we source a proper
/// Rive/Lottie orb animation. The painter creates a pulsing radial
/// glow that works on all platforms without crashes.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/aura_config.dart';

class SpectralAura extends StatefulWidget {
  const SpectralAura({super.key, required this.config, this.size = 200});

  final AuraConfig config;
  final double size;

  @override
  State<SpectralAura> createState() => _SpectralAuraState();
}

class _SpectralAuraState extends State<SpectralAura>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _breathController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breathController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _breathController,
            _shimmerController,
          ]),
          builder: (context, _) => CustomPaint(
            painter: _AuraPainter(
              config: widget.config,
              pulsePhase: _pulseController.value,
              breathPhase: CurveTween(
                curve: Curves.easeInOutSine,
              ).evaluate(_breathController),
              shimmerAngle: _shimmerController.value * 2 * math.pi,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.config,
    required this.pulsePhase,
    required this.breathPhase,
    required this.shimmerAngle,
  });

  final AuraConfig config;
  final double pulsePhase;
  final double breathPhase;
  final double shimmerAngle;

  static const _ringCount = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final i = config.intensity;
    final c1 = config.primaryColor;
    final c2 = config.secondaryColor;

    // Ambient bloom
    canvas.drawCircle(
      center,
      maxR * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          maxR * 0.9,
          [
            c1.withValues(alpha: 0.15 * i),
            c2.withValues(alpha: 0.06 * i),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35),
    );

    // Radiating rings
    for (int r = 0; r < _ringCount; r++) {
      final ringPhase = (pulsePhase + r / _ringCount) % 1.0;
      final ringRadius = maxR * (0.12 + ringPhase * 0.75);
      final life = math.sin(ringPhase * math.pi);
      final alpha = life * 0.55 * i;
      if (alpha < 0.01) continue;

      final ringColor = Color.lerp(
        c1,
        c2,
        (r / (_ringCount - 1)).clamp(0.0, 1.0),
      )!;
      final strokeW = maxR * 0.10 * (1.0 - ringPhase * 0.4);

      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = ringColor.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + ringPhase * 20),
      );

      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW * 2.5
          ..color = ringColor.withValues(alpha: alpha * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + ringPhase * 25),
      );
    }

    // Core
    final breathScale = 0.93 + math.sin(breathPhase * 2 * math.pi) * 0.07;
    final coreR = maxR * 0.15 * breathScale;

    canvas.drawCircle(
      center,
      coreR * 4,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          coreR * 4,
          [
            c1.withValues(alpha: 0.35 * i),
            Color.lerp(c1, c2, 0.5)!.withValues(alpha: 0.12 * i),
            Colors.transparent,
          ],
          [0.0, 0.35, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          coreR,
          [
            Colors.white.withValues(alpha: 0.7 * i),
            c1.withValues(alpha: 0.9 * i),
            c1.withValues(alpha: 0.3 * i),
            Colors.transparent,
          ],
          [0.0, 0.25, 0.6, 1.0],
        ),
    );

    // Shimmer
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(shimmerAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(
      center,
      maxR * 0.55,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.10 * i),
            Colors.white.withValues(alpha: 0.04 * i),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0.0, 0.05, 0.12, 0.18, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: maxR * 0.55))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      pulsePhase != old.pulsePhase ||
      breathPhase != old.breathPhase ||
      shimmerAngle != old.shimmerAngle ||
      config.primaryColor != old.config.primaryColor ||
      config.secondaryColor != old.config.secondaryColor;
}
