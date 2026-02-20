/// Voronoi mosaic painter for health score visualisation.
///
/// Fills a rounded rectangle with animated organic tiles whose colours
/// represent a score on a blue (low) → red (high) spectrum.
///
/// Architecture:
///   Private Voronoi engine  – seed generation, ray-casting, cell
///                             construction, Chaikin smoothing.
///   [VoronoiMosaicPainter]  – the public [CustomPainter] that drives
///                             the per-tile zoom-in → glow → settle
///                             animation and colour distribution.
///
/// ⚠ Geometry is O(n² × rays). It is cached in a static field keyed by
/// [VoronoiMosaicPainter.seed] and only recomputed when the seed changes.
/// The [paint] method only iterates cached paths.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================================
// Constants
// ============================================================================

/// Tuning knobs collected in one place so they're easy to adjust.
abstract final class _Config {
  static const int rayCount = 80;
  static const int chaikinPasses = 3;

  // Grid seed generation
  static const double jitterFactor = 0.7; // ±35 % of cell step
  static const double minDistFactor = 0.3; // 30 % of cell → squared = 0.09

  // Phantom border seeds
  static const double phantomPad = 0.5; // × cellSize
  static const double phantomJitter = 0.15; // × cellSize
  static const double phantomStep = 0.5; // × cellSize
  static const double cornerPad = 0.45; // × cellSize

  // Voronoi cell construction
  static const double groutFactor = 0.006; // × maxDim
  static const double searchRadiusFactor = 0.5; // × maxDim
  static const double expandPadFactor = 2.0; // × cellSize

  // Animation timeline
  static const double cycleLength = 0.25;
  static const double peakScale = 1.08;
  static const double peakGlow = 0.3;

  // Colour distribution
  static const double warmFloor = 0.40;
  static const double coolFloor = 0.2;
}

// ============================================================================
// Cached geometry
// ============================================================================

/// Pre-computed Voronoi mosaic — geometry that NEVER changes per-frame.
class _CachedMosaic {
  const _CachedMosaic({
    required this.key,
    required this.size,
    required this.paths,
    required this.centers,
    required this.order,
    required this.colorRandoms,
  });

  final int key;
  final Size size;

  /// Closed [Path] for each visible tile.
  final List<Path> paths;

  /// Seed point (centre) of each visible tile, used as scale origin.
  final List<Offset> centers;

  /// Randomised appearance ordering (index → tile index).
  final List<int> order;

  /// Deterministic per-tile random value ∈ [0, 1) for colour computation.
  final List<double> colorRandoms;
}

// ============================================================================
// Seed generation
// ============================================================================

/// Centred grid of jittered seeds.
///
/// Uses `round()` and fits step sizes to the card so left ≡ right and
/// top ≡ bottom by construction.
List<Offset> _gridSeeds(
  double width,
  double height,
  int tileCount,
  math.Random rng,
) {
  final cellSize = math.sqrt(width * height / tileCount);
  final cols = math.max(1, (width / cellSize).round());
  final rows = math.max(1, (height / cellSize).round());
  final xStep = width / cols;
  final yStep = height / rows;
  final jitterX = xStep * _Config.jitterFactor;
  final jitterY = yStep * _Config.jitterFactor;
  final minDist2 =
      cellSize * cellSize * _Config.minDistFactor * _Config.minDistFactor;
  final seeds = <Offset>[];

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final candidate = Offset(
        ((c + 0.5) * xStep + (rng.nextDouble() - 0.5) * jitterX)
            .clamp(0.0, width),
        ((r + 0.5) * yStep + (rng.nextDouble() - 0.5) * jitterY)
            .clamp(0.0, height),
      );
      if (!_tooClose(candidate, seeds, minDist2)) seeds.add(candidate);
    }
  }
  return seeds;
}

/// Returns `true` when [candidate] is within √[minDist2] of any seed.
bool _tooClose(Offset candidate, List<Offset> seeds, double minDist2) {
  for (int k = seeds.length - 1; k >= 0; k--) {
    final dx = candidate.dx - seeds[k].dx;
    final dy = candidate.dy - seeds[k].dy;
    if (dx * dx + dy * dy < minDist2) return true;
  }
  return false;
}

/// Phantom seeds forming a dense ring just outside the visible rect.
///
/// They participate in Voronoi computation but their cells are discarded,
/// pushing visible edge-tile boundaries inward for organic rounded edges.
List<Offset> _borderSeeds(
  double width,
  double height,
  double cellSize,
  math.Random rng,
) {
  final pad = cellSize * _Config.phantomPad;
  final jt = cellSize * _Config.phantomJitter;
  final step = cellSize * _Config.phantomStep;
  final seeds = <Offset>[];

  // Top and bottom edges
  final hSteps = (width / step).ceil() + 2;
  for (int i = 0; i < hSteps; i++) {
    final x = (i - 0.5) * step + (rng.nextDouble() - 0.5) * jt;
    seeds.add(Offset(x, -pad + (rng.nextDouble() - 0.5) * jt));
    seeds.add(Offset(x, height + pad + (rng.nextDouble() - 0.5) * jt));
  }

  // Left and right edges
  final vSteps = (height / step).ceil() + 2;
  for (int i = 0; i < vSteps; i++) {
    final y = (i - 0.5) * step + (rng.nextDouble() - 0.5) * jt;
    seeds.add(Offset(-pad + (rng.nextDouble() - 0.5) * jt, y));
    seeds.add(Offset(width + pad + (rng.nextDouble() - 0.5) * jt, y));
  }

  // Corner diagonal seeds
  final cPad = cellSize * _Config.cornerPad;
  seeds.addAll([
    Offset(-cPad, -cPad),
    Offset(width + cPad, -cPad),
    Offset(-cPad, height + cPad),
    Offset(width + cPad, height + cPad),
  ]);

  return seeds;
}

// ============================================================================
// Ray–container intersection
// ============================================================================

/// Distance from [origin] along unit [dir] to the nearest edge of [rect].
double _rayRectDist(Offset origin, Offset dir, Rect rect) {
  var tMin = double.infinity;

  if (dir.dx != 0) {
    for (final xEdge in [rect.left, rect.right]) {
      final t = (xEdge - origin.dx) / dir.dx;
      if (t > 0) {
        final y = origin.dy + t * dir.dy;
        if (y >= rect.top && y <= rect.bottom) tMin = math.min(tMin, t);
      }
    }
  }
  if (dir.dy != 0) {
    for (final yEdge in [rect.top, rect.bottom]) {
      final t = (yEdge - origin.dy) / dir.dy;
      if (t > 0) {
        final x = origin.dx + t * dir.dx;
        if (x >= rect.left && x <= rect.right) tMin = math.min(tMin, t);
      }
    }
  }
  return tMin;
}

// ============================================================================
// Cell construction
// ============================================================================

/// Chaikin corner-cutting on a closed polygon.
///
/// Each pass replaces every edge (A→B) with two points at 75 %/25 % and
/// 25 %/75 %. **3 passes** recommended — 5+ causes path shrinkage.
List<Offset> _chaikinSmooth(List<Offset> points, int passes) {
  var pts = points;
  for (int p = 0; p < passes; p++) {
    final n = pts.length;
    final out = List<Offset>.filled(n * 2, Offset.zero);
    for (int i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      out[i * 2] =
          Offset(a.dx * 0.75 + b.dx * 0.25, a.dy * 0.75 + b.dy * 0.25);
      out[i * 2 + 1] =
          Offset(a.dx * 0.25 + b.dx * 0.75, a.dy * 0.25 + b.dy * 0.75);
    }
    pts = out;
  }
  return pts;
}

/// Build Voronoi cell [Path]s from [seeds].
///
/// For each seed, casts [_Config.rayCount] rays. Per ray the minimum of
/// (container-edge distance, bisector distance to each neighbour within
/// [searchRadius]) minus [grout] gives the boundary point. The boundary
/// is smoothed with Chaikin corner-cutting then converted to a closed
/// [Path].
List<Path> _buildVoronoiCells({
  required List<Offset> seeds,
  required Rect bounds,
  required double grout,
  required double searchRadius,
}) {
  final searchR2 = searchRadius * searchRadius;
  final rayCount = _Config.rayCount;
  final paths = <Path>[];

  for (int i = 0; i < seeds.length; i++) {
    final seed = seeds[i];
    final boundary = List<Offset>.filled(rayCount, Offset.zero);

    for (int r = 0; r < rayCount; r++) {
      final angle = 2.0 * math.pi * r / rayCount;
      final dir = Offset(math.cos(angle), math.sin(angle));

      var minDist = _rayRectDist(seed, dir, bounds);

      for (int j = 0; j < seeds.length; j++) {
        if (j == i) continue;
        final dx = seeds[j].dx - seed.dx;
        final dy = seeds[j].dy - seed.dy;
        if (dx * dx + dy * dy > searchR2) continue;

        final dot = dir.dx * dx + dir.dy * dy;
        if (dot <= 0) continue;

        final bd = (dx * dx + dy * dy) / (2.0 * dot);
        if (bd < minDist) minDist = bd;
      }

      minDist = math.max(minDist - grout, 0.5);
      boundary[r] = Offset(seed.dx + minDist * dir.dx,
          seed.dy + minDist * dir.dy);
    }

    final smoothed = _chaikinSmooth(boundary, _Config.chaikinPasses);
    final path = Path()..moveTo(smoothed.first.dx, smoothed.first.dy);
    for (int k = 1; k < smoothed.length; k++) {
      path.lineTo(smoothed[k].dx, smoothed[k].dy);
    }
    path.close();
    paths.add(path);
  }
  return paths;
}

// ============================================================================
// Per-tile animation helpers
// ============================================================================

/// Returns (scale, glow, opacity) for a tile at [localT] ∈ [0, 1].
({double scale, double glow, double opacity}) _tileAnimation(double localT) {
  if (localT < 0.3) {
    final t = localT / 0.3;
    final e = 1.0 - math.pow(1.0 - t, 3); // easeOutCubic
    return (
      scale: e * _Config.peakScale,
      glow: e * _Config.peakGlow,
      opacity: e,
    );
  } else if (localT < 0.5) {
    return (
      scale: _Config.peakScale,
      glow: _Config.peakGlow,
      opacity: 1.0,
    );
  } else if (localT < 0.8) {
    final t = (localT - 0.5) / 0.3;
    final e = t * t * t; // easeInCubic
    return (
      scale: _Config.peakScale - e * (_Config.peakScale - 1.0),
      glow: _Config.peakGlow * (1.0 - e),
      opacity: 1.0,
    );
  }
  return (scale: 1.0, glow: 0.0, opacity: 1.0);
}

// ============================================================================
// Public painter
// ============================================================================

/// Fills a rectangle with an animated Voronoi mosaic.
///
/// Tile colours represent a score on a blue → red spectrum. Tiles appear
/// one-by-one with a zoom-in → glow → zoom-out → settle animation.
///
/// **Usage:**
/// ```dart
/// CustomPaint(
///   painter: VoronoiMosaicPainter(
///     animationProgress: controller.value, // raw 0→1
///     targetScore: 0.72,                   // health score for colours
///     seed: _seed,                         // change for fresh pattern
///   ),
/// )
/// ```
class VoronoiMosaicPainter extends CustomPainter {
  /// Creates a Voronoi mosaic painter.
  ///
  /// * [animationProgress] — raw controller value 0→1 (NOT score-mapped).
  /// * [targetScore] — final health score 0→1 for colour computation.
  /// * [seed] — deterministic random seed; change on each animation start.
  /// * [tileCount] — target number of visible tiles (actual may differ).
  /// * [backgroundColor] — grout / background colour.
  const VoronoiMosaicPainter({
    required this.animationProgress,
    required this.targetScore,
    required this.seed,
    this.tileCount = 60,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.coolColor = const Color(0xFF60A5FA),
    this.warmColor = const Color(0xFFE84545),
  });

  final double animationProgress;
  final double targetScore;
  final int seed;
  final int tileCount;
  final Color backgroundColor;

  /// Low-score colour endpoint (blue).
  final Color coolColor;

  /// High-score colour endpoint (red).
  final Color warmColor;

  // ---- Geometry cache (static — shared across instances) ----
  static _CachedMosaic? _cache;

  _CachedMosaic _ensureCache(Size size) {
    if (_cache != null && _cache!.key == seed && _cache!.size == size) {
      return _cache!;
    }

    final rng = math.Random(seed);
    final maxDim = math.max(size.width, size.height);
    final cellSize = math.sqrt(size.width * size.height / tileCount);

    // Interior seeds (visible tiles)
    final interiorSeeds = _gridSeeds(size.width, size.height, tileCount, rng);
    final interiorCount = interiorSeeds.length;

    // Phantom border seeds — push edge tiles inward for organic boundaries
    final phantomSeeds = _borderSeeds(size.width, size.height, cellSize, rng);

    // All seeds: interior first, then phantom
    final allSeeds = [...interiorSeeds, ...phantomSeeds];

    // Expanded rect so phantom seeds have valid ray intersections
    final expandPad = cellSize * _Config.expandPadFactor;
    final expandedRect = Rect.fromLTWH(
      -expandPad,
      -expandPad,
      size.width + expandPad * 2,
      size.height + expandPad * 2,
    );

    final allPaths = _buildVoronoiCells(
      seeds: allSeeds,
      bounds: expandedRect,
      grout: maxDim * _Config.groutFactor,
      searchRadius: maxDim * _Config.searchRadiusFactor,
    );

    // Only keep interior tile paths — phantom cells are discarded
    final paths = allPaths.sublist(0, interiorCount);

    // Random appearance order (interior tiles only)
    final order = List<int>.generate(interiorCount, (i) => i)..shuffle(rng);

    // Pre-compute deterministic random values for tile colours
    final randoms =
        List<double>.generate(interiorCount, (_) => rng.nextDouble());

    _cache = _CachedMosaic(
      key: seed,
      size: size,
      paths: paths,
      centers: interiorSeeds,
      order: order,
      colorRandoms: randoms,
    );
    return _cache!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background fill
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final mosaic = _ensureCache(size);
    final n = mosaic.paths.length;
    if (n == 0 || animationProgress <= 0) return;

    // Uniform edge clip — trims any tile that pokes past the boundary,
    // matching the grout thickness between tiles.
    final grout = math.max(size.width, size.height) * _Config.groutFactor;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
      grout,
      grout,
      size.width - 2 * grout,
      size.height - 2 * grout,
    ));

    final s = targetScore.clamp(0.0, 1.0);

    // Colour distribution
    final warmCount = (n * (_Config.warmFloor + s * (1.0 - _Config.warmFloor)))
        .round();

    // Reverse mapping: tile index → appearance order position
    final tileOrder = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      tileOrder[mosaic.order[i]] = i;
    }

    final tilePaint = Paint()..style = PaintingStyle.fill;
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor;

    for (int i = 0; i < n; i++) {
      final orderIdx = tileOrder[i];
      final startT =
          (orderIdx / n) * (1.0 - _Config.cycleLength);
      final localT =
          ((animationProgress - startT) / _Config.cycleLength).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      // Tile colour (fixed by targetScore, not animated progress)
      final cr = mosaic.colorRandoms[i];
      final Color tileColor;
      if (orderIdx < warmCount) {
        final t = s + cr * (1.0 - s);
        tileColor = Color.lerp(coolColor, warmColor, t)!;
      } else {
        final lo = (s - 0.3).clamp(_Config.coolFloor, 1.0);
        final hi = math.max(s, lo + 0.05);
        tileColor = Color.lerp(coolColor, warmColor, lo + cr * (hi - lo))!;
      }

      // Per-tile animation
      final anim = _tileAnimation(localT);

      final glowed = Color.lerp(tileColor, Colors.white, anim.glow)!;
      tilePaint.color = glowed.withValues(alpha: anim.opacity);

      // Gap prevention: dark base tile at full size first
      canvas.drawPath(mosaic.paths[i], basePaint);

      // Draw animated tile (with scale transform when needed)
      if ((anim.scale - 1.0).abs() > 0.001) {
        final center = mosaic.centers[i];
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(anim.scale);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawPath(mosaic.paths[i], tilePaint);
        canvas.restore();
      } else {
        canvas.drawPath(mosaic.paths[i], tilePaint);
      }
    }

    canvas.restore(); // end edge clip
  }

  @override
  bool shouldRepaint(VoronoiMosaicPainter old) =>
      animationProgress != old.animationProgress ||
      targetScore != old.targetScore ||
      seed != old.seed;
}

// ============================================================================
// Solid (single-colour) Voronoi mosaic painter
// ============================================================================

/// A static Voronoi mosaic where every tile is the same [tileColor].
///
/// Uses the same tile geometry, grout, and edge-clipping as
/// [VoronoiMosaicPainter] so the two look identical in size and gaps.
/// No animation, no colour distribution — just solid tiles.
///
/// ```dart
/// ClipOval(
///   child: CustomPaint(
///     size: const Size(100, 100),
///     painter: VoronoiSolidPainter(
///       tileColor: Colors.red,
///       seed: 42,
///       tileCount: 16,
///     ),
///   ),
/// )
/// ```
class VoronoiSolidPainter extends CustomPainter {
  const VoronoiSolidPainter({
    required this.tileColor,
    required this.seed,
    this.tileCount = 60,
    this.backgroundColor = const Color(0xFF1E1E1E),
  });

  /// Colour applied to every tile.
  final Color tileColor;

  /// Deterministic random seed for the Voronoi pattern.
  final int seed;

  /// Target number of visible tiles.
  final int tileCount;

  /// Grout / background colour.
  final Color backgroundColor;

  // Separate static cache so it doesn't collide with VoronoiMosaicPainter.
  static _CachedMosaic? _cache;

  _CachedMosaic _ensureCache(Size size) {
    if (_cache != null && _cache!.key == seed && _cache!.size == size) {
      return _cache!;
    }

    final rng = math.Random(seed);
    final maxDim = math.max(size.width, size.height);
    final cellSize = math.sqrt(size.width * size.height / tileCount);

    final interiorSeeds = _gridSeeds(size.width, size.height, tileCount, rng);
    final interiorCount = interiorSeeds.length;
    final phantomSeeds = _borderSeeds(size.width, size.height, cellSize, rng);
    final allSeeds = [...interiorSeeds, ...phantomSeeds];

    final expandPad = cellSize * _Config.expandPadFactor;
    final expandedRect = Rect.fromLTWH(
      -expandPad,
      -expandPad,
      size.width + expandPad * 2,
      size.height + expandPad * 2,
    );

    final allPaths = _buildVoronoiCells(
      seeds: allSeeds,
      bounds: expandedRect,
      grout: maxDim * _Config.groutFactor,
      searchRadius: maxDim * _Config.searchRadiusFactor,
    );

    final paths = allPaths.sublist(0, interiorCount);

    _cache = _CachedMosaic(
      key: seed,
      size: size,
      paths: paths,
      centers: interiorSeeds,
      // order and colorRandoms unused but required by the class
      order: List<int>.generate(interiorCount, (i) => i),
      colorRandoms: List<double>.filled(interiorCount, 0),
    );
    return _cache!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final mosaic = _ensureCache(size);
    if (mosaic.paths.isEmpty) return;

    final grout = math.max(size.width, size.height) * _Config.groutFactor;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
      grout,
      grout,
      size.width - 2 * grout,
      size.height - 2 * grout,
    ));

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = tileColor;

    for (final path in mosaic.paths) {
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(VoronoiSolidPainter old) =>
      tileColor != old.tileColor || seed != old.seed;
}

// ============================================================================
// Grouped Voronoi mosaic painter (tiles mapped to N colour groups)
// ============================================================================

/// Cached geometry + group assignments for [VoronoiGroupedPainter].
class _CachedGroupedMosaic {
  const _CachedGroupedMosaic({
    required this.key,
    required this.size,
    required this.paths,
    required this.centers,
    required this.order,
    required this.groupAssignments,
  });

  final int key;
  final Size size;
  final List<Path> paths;
  final List<Offset> centers;

  /// Randomised appearance ordering (index → tile index).
  final List<int> order;

  /// For each tile, which group index (0 .. groupCount-1) it belongs to.
  final List<int> groupAssignments;
}

/// A static Voronoi mosaic where tiles are randomly split into groups,
/// each painted with its own colour from [groupColors].
///
/// The tile geometry, grout, and edge-clipping match [VoronoiMosaicPainter]
/// exactly so the two look identical in shape and gaps.
///
/// Group assignment is deterministic (seeded by [seed]) and tiles are
/// distributed as evenly as possible across groups.
///
/// ```dart
/// CustomPaint(
///   painter: VoronoiGroupedPainter(
///     groupColors: [connectionColor, intimacyColor, peaceColor],
///     seed: 42,
///   ),
/// )
/// ```
class VoronoiGroupedPainter extends CustomPainter {
  const VoronoiGroupedPainter({
    required this.groupColors,
    required this.seed,
    this.animationProgress = 1.0,
    this.tileCount = 60,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.staggerSpread = 0.75,
  });

  /// One colour per group. Length determines group count.
  final List<Color> groupColors;

  /// Deterministic random seed.
  final int seed;

  /// Raw controller value 0→1. When < 1, tiles appear one-by-one with
  /// zoom-in → glow → zoom-out → settle. At 1.0 all tiles are settled.
  final double animationProgress;

  /// Target number of visible tiles.
  final int tileCount;

  /// Grout / background colour.
  final Color backgroundColor;

  /// How much of the timeline is used to spread tile start times (0→1).
  /// Lower = more tiles start at the same time (higher concurrency).
  /// Default 0.75 = tiles spread across 75% of timeline.
  /// Use 0.3–0.4 for faster, more concurrent appearance.
  final double staggerSpread;

  // Own static cache
  static _CachedGroupedMosaic? _cache;

  _CachedGroupedMosaic _ensureCache(Size size) {
    if (_cache != null && _cache!.key == seed && _cache!.size == size) {
      return _cache!;
    }

    final rng = math.Random(seed);
    final maxDim = math.max(size.width, size.height);
    final cellSize = math.sqrt(size.width * size.height / tileCount);

    final interiorSeeds = _gridSeeds(size.width, size.height, tileCount, rng);
    final interiorCount = interiorSeeds.length;
    final phantomSeeds = _borderSeeds(size.width, size.height, cellSize, rng);
    final allSeeds = [...interiorSeeds, ...phantomSeeds];

    final expandPad = cellSize * _Config.expandPadFactor;
    final expandedRect = Rect.fromLTWH(
      -expandPad,
      -expandPad,
      size.width + expandPad * 2,
      size.height + expandPad * 2,
    );

    final allPaths = _buildVoronoiCells(
      seeds: allSeeds,
      bounds: expandedRect,
      grout: maxDim * _Config.groutFactor,
      searchRadius: maxDim * _Config.searchRadiusFactor,
    );

    final paths = allPaths.sublist(0, interiorCount);

    // Random appearance order
    final order = List<int>.generate(interiorCount, (i) => i)..shuffle(rng);

    // Randomly assign tiles to groups (even distribution)
    final groupCount = groupColors.length.clamp(1, interiorCount);
    final indices = List<int>.generate(interiorCount, (i) => i)..shuffle(rng);
    final assignments = List<int>.filled(interiorCount, 0);
    for (int i = 0; i < interiorCount; i++) {
      assignments[indices[i]] = i % groupCount;
    }

    _cache = _CachedGroupedMosaic(
      key: seed,
      size: size,
      paths: paths,
      centers: interiorSeeds,
      order: order,
      groupAssignments: assignments,
    );
    return _cache!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final mosaic = _ensureCache(size);
    final n = mosaic.paths.length;
    if (n == 0 || groupColors.isEmpty || animationProgress <= 0) return;

    final grout = math.max(size.width, size.height) * _Config.groutFactor;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
      grout,
      grout,
      size.width - 2 * grout,
      size.height - 2 * grout,
    ));

    // Reverse mapping: tile index → appearance order position
    final tileOrder = List<int>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      tileOrder[mosaic.order[i]] = i;
    }

    final tilePaint = Paint()..style = PaintingStyle.fill;
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor;

    for (int i = 0; i < n; i++) {
      final group = mosaic.groupAssignments[i];
      final tileColor = groupColors[group.clamp(0, groupColors.length - 1)];

      // Settled — fast path
      if (animationProgress >= 1.0) {
        tilePaint.color = tileColor;
        canvas.drawPath(mosaic.paths[i], tilePaint);
        continue;
      }

      // Per-tile staggered zoom-in → glow → zoom-out → settle
      final orderIdx = tileOrder[i];
      final cycleFrac = 1.0 - staggerSpread; // fraction of timeline per tile
      final startT = (orderIdx / n) * staggerSpread;
      final localT =
          ((animationProgress - startT) / cycleFrac).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final anim = _tileAnimation(localT);
      final glowed = Color.lerp(tileColor, Colors.white, anim.glow)!;
      tilePaint.color = glowed.withValues(alpha: anim.opacity);

      // Dark base tile for gap prevention
      canvas.drawPath(mosaic.paths[i], basePaint);

      // Animated tile with scale
      if ((anim.scale - 1.0).abs() > 0.001) {
        final center = mosaic.centers[i];
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(anim.scale);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawPath(mosaic.paths[i], tilePaint);
        canvas.restore();
      } else {
        canvas.drawPath(mosaic.paths[i], tilePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(VoronoiGroupedPainter old) =>
      seed != old.seed ||
      animationProgress != old.animationProgress ||
      _colorsChanged(old.groupColors);

  bool _colorsChanged(List<Color> other) {
    if (groupColors.length != other.length) return true;
    for (int i = 0; i < groupColors.length; i++) {
      if (groupColors[i] != other[i]) return true;
    }
    return false;
  }
}
