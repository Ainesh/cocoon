/// Small Voronoi mosaic that can animate between full color and greyscale.
library;

import 'package:flutter/material.dart';

import '../painters/voronoi_mosaic_painter.dart';

/// A compact mosaic tile visualization that transitions between
/// vivid color and desaturated grey.
///
/// Used on the notification permission screen to show "what happens
/// if you don't come back."
class DesaturatingMosaic extends StatefulWidget {
  const DesaturatingMosaic({
    super.key,
    this.score = 0.7,
    this.isDesaturated = false,
    this.tileCount = 30,
    this.size = const Size(120, 80),
    this.seed,
  });

  final double score;
  final bool isDesaturated;
  final int tileCount;
  final Size size;
  final int? seed;

  @override
  State<DesaturatingMosaic> createState() => _DesaturatingMosaicState();
}

class _DesaturatingMosaicState extends State<DesaturatingMosaic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _seed;

  static const _vividCool = Color(0xFF60A5FA);
  static const _vividWarm = Color(0xFFE84545);
  static const _greyCool = Color(0xFF3A3A3A);
  static const _greyWarm = Color(0xFF4A4A4A);

  @override
  void initState() {
    super.initState();
    _seed = widget.seed ?? DateTime.now().millisecondsSinceEpoch;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: widget.isDesaturated ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(DesaturatingMosaic old) {
    super.didUpdateWidget(old);
    if (widget.isDesaturated != old.isDesaturated) {
      if (widget.isDesaturated) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final cool = Color.lerp(_vividCool, _greyCool, t)!;
        final warm = Color.lerp(_vividWarm, _greyWarm, t)!;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            size: widget.size,
            painter: VoronoiMosaicPainter(
              animationProgress: 1.0,
              targetScore: widget.score,
              seed: _seed,
              tileCount: widget.tileCount,
              coolColor: cool,
              warmColor: warm,
            ),
          ),
        );
      },
    );
  }
}
