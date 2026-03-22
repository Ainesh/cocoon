/// Custom animation curves for the Kairos app.
library;

import 'dart:math' as math;
import 'package:flutter/animation.dart';

/// Custom curve following normal distribution pattern.
///
/// Fast at start, progressively slower towards the end (right half of bell curve).
/// Used for the health score dot animation to create suspense.
class SuspensefulCurve extends Curve {
  const SuspensefulCurve({this.steepness = 3.5});

  /// Controls how dramatic the slowdown is at the end.
  /// Higher values = more dramatic slowdown.
  final double steepness;

  @override
  double transformInternal(double t) {
    // Progress = 1 - (1-t)^k where k controls the curve steepness
    // This creates: fast start -> gradual slowdown -> crawl at end
    return 1.0 - math.pow(1.0 - t, steepness).toDouble();
  }
}
