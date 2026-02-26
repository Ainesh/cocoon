/// Typed output models for the scoring engine.
///
/// All models are immutable value objects consumed by UI layers.
/// The engine produces [ScoreResult] as its top-level output.
library;

// ---------------------------------------------------------------------------
// Insight label
// ---------------------------------------------------------------------------

/// Reduced set of relationship-health insight labels (6 total).
/// Labels that read naturally in "_{label}_ over past 30 days".
enum InsightLabel {
  thriving('Thriving', 'High scores and stable or improving'),
  growing('Growing', 'Scores trending upward'),
  steady('Steady', 'Moderate scores and consistent'),
  cooling('Cooling', 'Slight downward trend'),
  struggling('Struggling', 'Significant decline or low scores'),
  justStarting('Just starting', 'Not enough data yet');

  const InsightLabel(this.displayName, this.description);

  final String displayName;
  final String description;
}

// ---------------------------------------------------------------------------
// Per-attribute score
// ---------------------------------------------------------------------------

/// Score and trend for a single pulse attribute.
class AttributeScore {
  const AttributeScore({
    required this.attributeId,
    required this.score,
    required this.trend,
    required this.weight,
  });

  /// Attribute identifier (e.g. 'connection', 'trust').
  final String attributeId;

  /// Average score for this attribute (0-100).
  final double score;

  /// Trend direction (-1 to 1, positive = improving).
  final double trend;

  /// Normalised weight in the current config (0-1).
  final double weight;

  @override
  String toString() =>
      'AttributeScore($attributeId, score=$score, trend=$trend, w=$weight)';
}

// ---------------------------------------------------------------------------
// Temporal aggregation models
// ---------------------------------------------------------------------------

/// Combined score for a single calendar day.
class DailyScore {
  const DailyScore({
    required this.date,
    required this.overallScore,
    required this.attributeScores,
    required this.hasCheckIn,
  });

  final DateTime date;

  /// Weighted overall score for this day (0-100).
  final double overallScore;

  /// Per-attribute combined averages for this day.
  final Map<String, double> attributeScores;

  /// Whether at least one check-in occurred on this day.
  final bool hasCheckIn;
}

/// Aggregated score for a calendar week.
class WeeklyScore {
  const WeeklyScore({
    required this.weekIndex,
    required this.startDate,
    required this.endDate,
    required this.overallScore,
    required this.hasData,
  });

  /// 0 = oldest week, 3 = most recent week in the 30-day window.
  final int weekIndex;

  final DateTime startDate;
  final DateTime endDate;

  /// Average of daily overall scores within this week.
  final double overallScore;

  /// True if at least one day in this week had check-in data.
  final bool hasData;
}

/// Aggregated score for the full 30-day period.
class MonthlyScore {
  const MonthlyScore({
    required this.overallScore,
    required this.weeklyScores,
  });

  /// Average of weekly overall scores.
  final double overallScore;

  final List<WeeklyScore> weeklyScores;
}

// ---------------------------------------------------------------------------
// Config snapshot (derived from check-in scores at read time)
// ---------------------------------------------------------------------------

/// Immutable snapshot of the pulse configuration at check-in time.
///
/// Convenience view of the pulse config at check-in time.
///
/// Reconstructed from the compact scores map:
/// ```json
/// "scores": { "connection": {"value": 80, "weight": 0.33}, ... }
/// ```
/// Active attributes = keys. Weights = the `weight` field per entry.
class ConfigSnapshot {
  const ConfigSnapshot({
    required this.activeAttributes,
    required this.weights,
  });

  /// Ordered list of attribute IDs that were active.
  final List<String> activeAttributes;

  /// Normalised weights keyed by attribute ID. Values sum to 1.0.
  final Map<String, double> weights;

  /// Construct from the compact scores map.
  factory ConfigSnapshot.fromScoresMap(Map<String, dynamic> scoresMap) {
    final attrs = <String>[];
    final weights = <String, double>{};
    for (final entry in scoresMap.entries) {
      attrs.add(entry.key);
      if (entry.value is Map) {
        weights[entry.key] =
            ((entry.value as Map)['weight'] as num?)?.toDouble() ?? 0;
      }
    }
    return ConfigSnapshot(activeAttributes: attrs, weights: weights);
  }

  @override
  String toString() => 'ConfigSnapshot(attrs=$activeAttributes)';
}

// ---------------------------------------------------------------------------
// Top-level engine output
// ---------------------------------------------------------------------------

/// The complete scoring result consumed by all UI surfaces.
///
/// Produced by [ScoreEngine.computeScoreResult].
class ScoreResult {
  const ScoreResult({
    required this.overallScore,
    required this.attributeScores,
    required this.attributeTrends,
    required this.overallTrend,
    required this.weeklyScores,
    required this.insight,
    required this.checkInCount,
    required this.userCheckInCount,
    required this.partnerCheckInCount,
    required this.streak,
    required this.weights,
  });

  /// Weighted overall score (0-100).
  final int overallScore;

  /// Per-attribute average scores (0-100).
  final Map<String, double> attributeScores;

  /// Per-attribute trend direction (-1..1).
  final Map<String, double> attributeTrends;

  /// Overall weighted trend (-1..1).
  final double overallTrend;

  /// 4 weekly scores for the trend chart.
  final List<WeeklyScore> weeklyScores;

  /// Human-readable insight label.
  final InsightLabel insight;

  /// Total check-in count in the 30-day window.
  final int checkInCount;

  /// Current user's check-in count.
  final int userCheckInCount;

  /// Partner's check-in count.
  final int partnerCheckInCount;

  /// Consecutive-day check-in streak.
  final int streak;

  /// Active config weights at computation time.
  final Map<String, double> weights;

  /// Empty result used when there is no data.
  static const empty = ScoreResult(
    overallScore: 0,
    attributeScores: {},
    attributeTrends: {},
    overallTrend: 0,
    weeklyScores: [],
    insight: InsightLabel.justStarting,
    checkInCount: 0,
    userCheckInCount: 0,
    partnerCheckInCount: 0,
    streak: 0,
    weights: {},
  );
}
