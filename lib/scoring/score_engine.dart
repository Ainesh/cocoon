/// Pure-Dart scoring engine for relationship health.
///
/// No Flutter dependencies — fully unit-testable.
///
/// ## Pipeline
///
/// 1. Collect [ScoreContribution]s from sources within a 30-day window.
/// 2. Group by day, then by user. Average each user's scores independently.
/// 3. Combine user averages into a combined daily score (equal user weight).
/// 4. Aggregate daily → weekly → monthly.
/// 5. Compute per-attribute and overall trends.
/// 6. Derive an [InsightLabel].
/// 7. Package everything into a [ScoreResult].
library;

import 'score_models.dart';
import 'score_source.dart';

class ScoreEngine {
  const ScoreEngine();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Compute the full [ScoreResult] from contributions in the last 30 days.
  ///
  /// [contributions] — all score contributions in the 30-day window.
  /// [currentWeights] — normalised weights from the current [PulseConfig].
  /// [currentUserId] — used to split user vs partner counts.
  /// [streak] — pre-computed consecutive-day streak.
  /// [referenceDate] — "now" for testability (defaults to DateTime.now()).
  ScoreResult computeScoreResult({
    required List<ScoreContribution> contributions,
    required Map<String, double> currentWeights,
    String? currentUserId,
    int streak = 0,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 29));

    // Filter to 30-day window (cutoff .. today inclusive)
    final inWindow = contributions
        .where(
          (c) =>
              !c.timestamp.isBefore(cutoff) &&
              c.timestamp.isBefore(today.add(const Duration(days: 1))),
        )
        .toList();

    if (inWindow.isEmpty) {
      return ScoreResult(
        overallScore: 0,
        attributeScores: {},
        attributeTrends: {},
        overallTrend: 0,
        weeklyScores: _emptyWeeklyScores(cutoff),
        insight: InsightLabel.justStarting,
        checkInCount: 0,
        userCheckInCount: 0,
        partnerCheckInCount: 0,
        streak: streak,
        weights: currentWeights,
      );
    }

    // Count check-ins
    final totalCount = inWindow.length;
    final userCount = currentUserId != null
        ? inWindow.where((c) => c.userId == currentUserId).length
        : 0;
    final partnerCount = totalCount - userCount;

    // Step 1: Compute daily scores
    final dailyScores = _computeDailyScores(
      inWindow,
      currentWeights,
      cutoff,
      today,
    );

    // Step 2: Compute weekly scores
    final weeklyScores = _computeWeeklyScores(dailyScores, cutoff);

    // Step 3: Compute monthly score
    final monthlyScore = _computeMonthlyScore(weeklyScores);

    // Step 4: Compute per-attribute averages and trends
    final attrScores = _computeAttributeAverages(dailyScores, currentWeights);
    final attrTrends = _computeAttributeTrends(dailyScores, currentWeights);

    // Step 5: Overall trend (weighted average of attribute trends)
    final overallTrend = _computeOverallTrend(attrTrends, currentWeights);

    // Step 6: Overall score
    final overallScore = monthlyScore.overallScore.round().clamp(0, 100);

    // Step 7: Insight label
    final insight = _computeInsight(
      overallScore: overallScore,
      overallTrend: overallTrend,
      checkInCount: totalCount,
      dailyScores: dailyScores,
    );

    return ScoreResult(
      overallScore: overallScore,
      attributeScores: attrScores,
      attributeTrends: attrTrends,
      overallTrend: overallTrend,
      weeklyScores: weeklyScores,
      insight: insight,
      checkInCount: totalCount,
      userCheckInCount: userCount,
      partnerCheckInCount: partnerCount,
      streak: streak,
      weights: currentWeights,
    );
  }

  // -------------------------------------------------------------------------
  // Daily scores
  // -------------------------------------------------------------------------

  List<DailyScore> _computeDailyScores(
    List<ScoreContribution> contributions,
    Map<String, double> currentWeights,
    DateTime cutoff,
    DateTime today,
  ) {
    // Group by calendar day
    final byDay = <String, List<ScoreContribution>>{};
    for (final c in contributions) {
      final key = _dayKey(c.timestamp);
      byDay.putIfAbsent(key, () => []).add(c);
    }

    final result = <DailyScore>[];
    for (int i = 0; i < 30; i++) {
      final date = cutoff.add(Duration(days: i));
      final key = _dayKey(date);
      final dayContributions = byDay[key];

      if (dayContributions == null || dayContributions.isEmpty) {
        result.add(
          DailyScore(
            date: date,
            overallScore: 0,
            attributeScores: {},
            hasCheckIn: false,
          ),
        );
        continue;
      }

      // Group by user, average each user's scores independently
      final byUser = <String, List<ScoreContribution>>{};
      for (final c in dayContributions) {
        byUser.putIfAbsent(c.userId, () => []).add(c);
      }

      // Per-user: compute attribute averages AND per-check-in overall scores
      // Each check-in's overall uses its own saved configSnapshot weights.
      final userAttrAvgs = <String, Map<String, double>>{};
      final userOveralls = <String, double>{};

      for (final entry in byUser.entries) {
        final userId = entry.key;
        final userContribs = entry.value;
        final attrSums = <String, double>{};
        final attrCounts = <String, int>{};

        // Compute per-check-in overall using saved config weights
        double overallSum = 0;
        for (final c in userContribs) {
          // Attribute-level aggregation
          for (final attrEntry in c.attributeScores.entries) {
            attrSums[attrEntry.key] =
                (attrSums[attrEntry.key] ?? 0) + attrEntry.value;
            attrCounts[attrEntry.key] = (attrCounts[attrEntry.key] ?? 0) + 1;
          }

          // Per-check-in overall using THIS check-in's saved config
          final ciWeights = c.configSnapshot.weights;
          double ciWeightedSum = 0;
          double ciWeightTotal = 0;
          for (final attrEntry in c.attributeScores.entries) {
            final w = ciWeights[attrEntry.key] ?? 0;
            ciWeightedSum += attrEntry.value * w;
            ciWeightTotal += w;
          }
          overallSum += ciWeightTotal > 0 ? ciWeightedSum / ciWeightTotal : 0.0;
        }

        // User's attribute averages
        final avgs = <String, double>{};
        for (final attr in attrSums.keys) {
          avgs[attr] = attrSums[attr]! / attrCounts[attr]!;
        }
        userAttrAvgs[userId] = avgs;

        // User's daily overall = avg of their per-check-in overalls
        userOveralls[userId] = overallSum / userContribs.length;
      }

      // Combine user attribute averages (equal weight per user)
      final combinedAttrs = <String, double>{};
      final allAttrs = <String>{};
      for (final avgs in userAttrAvgs.values) {
        allAttrs.addAll(avgs.keys);
      }

      for (final attr in allAttrs) {
        double sum = 0;
        int count = 0;
        for (final avgs in userAttrAvgs.values) {
          if (avgs.containsKey(attr)) {
            sum += avgs[attr]!;
            count++;
          }
        }
        combinedAttrs[attr] = sum / count;
      }

      // Combined daily overall = avg of user overalls (each user weighted equally)
      final combinedOverall = userOveralls.values.isNotEmpty
          ? userOveralls.values.reduce((a, b) => a + b) / userOveralls.length
          : 0.0;

      result.add(
        DailyScore(
          date: date,
          overallScore: combinedOverall,
          attributeScores: combinedAttrs,
          hasCheckIn: true,
        ),
      );
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Weekly scores
  // -------------------------------------------------------------------------

  List<WeeklyScore> _computeWeeklyScores(
    List<DailyScore> dailyScores,
    DateTime cutoff,
  ) {
    // 4 weeks: [0..6], [7..13], [14..20], [21..29]
    final weekRanges = [
      [0, 7],
      [7, 14],
      [14, 21],
      [21, 30],
    ];

    return List.generate(weekRanges.length, (i) {
      final range = weekRanges[i];
      final weekDays = dailyScores
          .skip(range[0])
          .take(range[1] - range[0])
          .where((d) => d.hasCheckIn)
          .toList();

      final hasData = weekDays.isNotEmpty;
      final avgScore = hasData
          ? weekDays.map((d) => d.overallScore).reduce((a, b) => a + b) /
                weekDays.length
          : 0.0;

      return WeeklyScore(
        weekIndex: i,
        startDate: cutoff.add(Duration(days: range[0])),
        endDate: cutoff.add(Duration(days: range[1] - 1)),
        overallScore: avgScore,
        hasData: hasData,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Monthly score
  // -------------------------------------------------------------------------

  MonthlyScore _computeMonthlyScore(List<WeeklyScore> weeklyScores) {
    final withData = weeklyScores.where((w) => w.hasData).toList();
    final overall = withData.isNotEmpty
        ? withData.map((w) => w.overallScore).reduce((a, b) => a + b) /
              withData.length
        : 0.0;

    return MonthlyScore(overallScore: overall, weeklyScores: weeklyScores);
  }

  // -------------------------------------------------------------------------
  // Attribute averages
  // -------------------------------------------------------------------------

  Map<String, double> _computeAttributeAverages(
    List<DailyScore> dailyScores,
    Map<String, double> weights,
  ) {
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final day in dailyScores) {
      if (!day.hasCheckIn) continue;
      for (final entry in day.attributeScores.entries) {
        sums[entry.key] = (sums[entry.key] ?? 0) + entry.value;
        counts[entry.key] = (counts[entry.key] ?? 0) + 1;
      }
    }

    return sums.map((k, v) => MapEntry(k, v / (counts[k] ?? 1)));
  }

  // -------------------------------------------------------------------------
  // Attribute trends
  // -------------------------------------------------------------------------

  Map<String, double> _computeAttributeTrends(
    List<DailyScore> dailyScores,
    Map<String, double> weights,
  ) {
    final daysWithData = dailyScores.where((d) => d.hasCheckIn).toList();
    if (daysWithData.length < 4) {
      // Not enough data for meaningful trends
      return weights.map((k, _) => MapEntry(k, 0.0));
    }

    final mid = daysWithData.length ~/ 2;
    final olderHalf = daysWithData.sublist(0, mid);
    final newerHalf = daysWithData.sublist(mid);

    final allAttrs = <String>{};
    for (final day in daysWithData) {
      allAttrs.addAll(day.attributeScores.keys);
    }

    final trends = <String, double>{};
    for (final attr in allAttrs) {
      final olderScores = olderHalf
          .where((d) => d.attributeScores.containsKey(attr))
          .toList();
      final newerScores = newerHalf
          .where((d) => d.attributeScores.containsKey(attr))
          .toList();

      if (olderScores.isEmpty || newerScores.isEmpty) {
        trends[attr] = 0;
        continue;
      }

      final olderAvg =
          olderScores
              .map((d) => d.attributeScores[attr]!)
              .reduce((a, b) => a + b) /
          olderScores.length;
      final newerAvg =
          newerScores
              .map((d) => d.attributeScores[attr]!)
              .reduce((a, b) => a + b) /
          newerScores.length;

      // Normalise: max possible change is 100 (from 0 to 100 or vice versa)
      trends[attr] = ((newerAvg - olderAvg) / 100).clamp(-1.0, 1.0);
    }

    return trends;
  }

  // -------------------------------------------------------------------------
  // Overall trend
  // -------------------------------------------------------------------------

  double _computeOverallTrend(
    Map<String, double> attrTrends,
    Map<String, double> weights,
  ) {
    if (attrTrends.isEmpty) return 0;

    double weightedSum = 0;
    double weightTotal = 0;
    for (final attr in attrTrends.keys) {
      final w = weights[attr] ?? 0;
      weightedSum += attrTrends[attr]! * w;
      weightTotal += w;
    }
    return weightTotal > 0 ? (weightedSum / weightTotal).clamp(-1.0, 1.0) : 0.0;
  }

  // -------------------------------------------------------------------------
  // Insight
  // -------------------------------------------------------------------------

  InsightLabel _computeInsight({
    required int overallScore,
    required double overallTrend,
    required int checkInCount,
    required List<DailyScore> dailyScores,
  }) {
    if (checkInCount < 4) return InsightLabel.justStarting;

    // Variance check
    final daysWithData = dailyScores.where((d) => d.hasCheckIn).toList();
    double variance = 0;
    if (daysWithData.length >= 2) {
      final mean =
          daysWithData.map((d) => d.overallScore).reduce((a, b) => a + b) /
          daysWithData.length;
      variance =
          daysWithData
              .map((d) => (d.overallScore - mean) * (d.overallScore - mean))
              .reduce((a, b) => a + b) /
          daysWithData.length;
    }

    // Decision tree
    if (overallScore < 40 || overallTrend < -0.3) {
      return InsightLabel.struggling;
    }
    if (overallTrend < -0.15) {
      return InsightLabel.cooling;
    }
    if (overallScore >= 75 && overallTrend >= -0.05) {
      return InsightLabel.thriving;
    }
    if (overallTrend > 0.15) {
      return InsightLabel.growing;
    }
    // Moderate + stable (low variance)
    if (variance < _varianceThreshold) {
      return InsightLabel.steady;
    }
    // Default to steady for remaining cases
    return InsightLabel.steady;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static const double _varianceThreshold = 200;

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  List<WeeklyScore> _emptyWeeklyScores(DateTime cutoff) {
    final ranges = [
      [0, 7],
      [7, 14],
      [14, 21],
      [21, 30],
    ];
    return List.generate(
      ranges.length,
      (i) => WeeklyScore(
        weekIndex: i,
        startDate: cutoff.add(Duration(days: ranges[i][0])),
        endDate: cutoff.add(Duration(days: ranges[i][1] - 1)),
        overallScore: 0,
        hasData: false,
      ),
    );
  }
}
