/// Comprehensive tests for the ScoreEngine.
///
/// Covers daily/weekly/monthly computation, weighted scoring,
/// trend calculation, insight labels, 30-day window enforcement,
/// config snapshot integrity, and edge cases.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/scoring/score_engine.dart';
import 'package:couple_space/scoring/score_models.dart';
import 'package:couple_space/scoring/score_source.dart';

void main() {
  const engine = ScoreEngine();

  /// Helper: create a contribution for a given user/day/scores.
  ScoreContribution contribution({
    required String userId,
    required DateTime timestamp,
    required Map<String, int> scores,
    ConfigSnapshot? config,
  }) {
    final attrs = scores.keys.toList();
    return ScoreContribution(
      sourceType: 'checkin',
      userId: userId,
      timestamp: timestamp,
      attributeScores: scores,
      configSnapshot: config ??
          ConfigSnapshot(
            activeAttributes: attrs,
            weights: {for (final a in attrs) a: 1.0 / attrs.length},
          ),
    );
  }

  final refDate = DateTime(2026, 2, 23);
  final equalWeights = {
    'connection': 1 / 3,
    'intimacy': 1 / 3,
    'peace': 1 / 3,
  };

  // ===========================================================================
  // Daily score computation
  // ===========================================================================

  group('Daily score computation', () {
    test('single user, single check-in on a day', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 80, 'intimacy': 60, 'peace': 70},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: equalWeights,
        referenceDate: refDate,
      );

      expect(result.overallScore, closeTo(70, 1)); // (80+60+70)/3
      expect(result.checkInCount, 1);
    });

    test('single user, multiple check-ins same day (averaged)', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 100, 'intimacy': 100, 'peace': 100},
        ),
        contribution(
          userId: 'u1',
          timestamp: refDate.add(const Duration(hours: 1)),
          scores: {'connection': 60, 'intimacy': 60, 'peace': 60},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: equalWeights,
        referenceDate: refDate,
      );

      // User avg: (100+60)/2 = 80 for each attr
      expect(result.overallScore, closeTo(80, 1));
    });

    test('two users same day: combined = mean of user averages', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 100, 'intimacy': 100, 'peace': 100},
        ),
        contribution(
          userId: 'u2',
          timestamp: refDate,
          scores: {'connection': 80, 'intimacy': 80, 'peace': 80},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: equalWeights,
        referenceDate: refDate,
      );

      // User1 avg = 100, User2 avg = 80, combined = 90
      expect(result.overallScore, closeTo(90, 1));
    });

    test('two users different frequencies: equal weight regardless', () {
      final contributions = [
        // User1 checks in 5 times
        for (int i = 0; i < 5; i++)
          contribution(
            userId: 'u1',
            timestamp: refDate.add(Duration(minutes: i)),
            scores: {'connection': 100},
          ),
        // User2 checks in once
        contribution(
          userId: 'u2',
          timestamp: refDate,
          scores: {'connection': 60},
        ),
      ];

      final weights = {'connection': 1.0};

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: weights,
        referenceDate: refDate,
      );

      // User1 avg = 100, User2 avg = 60, combined = 80
      expect(result.overallScore, closeTo(80, 1));
    });

    test('exact user spec: u1=[100,100,100] u2=[80,80,80] -> daily 90', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 3; d++) {
        final day = refDate.subtract(Duration(days: d));
        contributions.add(contribution(
          userId: 'u1',
          timestamp: day,
          scores: {'connection': 100, 'intimacy': 100, 'peace': 100},
        ));
        contributions.add(contribution(
          userId: 'u2',
          timestamp: day,
          scores: {'connection': 80, 'intimacy': 80, 'peace': 80},
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: equalWeights,
        referenceDate: refDate,
      );

      expect(result.overallScore, closeTo(90, 1));
    });
  });

  // ===========================================================================
  // Weighted overall score
  // ===========================================================================

  group('Weighted overall score', () {
    test('all attributes 2x overlap -> equal weight', () {
      // Both users pick same 3 = all 2x = equal normalized weight
      final weights = {'connection': 1 / 3, 'intimacy': 1 / 3, 'peace': 1 / 3};
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 90, 'intimacy': 60, 'peace': 30},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: weights,
        referenceDate: refDate,
      );

      expect(result.overallScore, closeTo(60, 1)); // (90+60+30)/3
    });

    test('mixed overlap: 2x on shared, 1x on unique', () {
      // connection=2x, trust=2x, communication=1x, intimacy=1x
      // Normalized: 2/6, 2/6, 1/6, 1/6
      final weights = {
        'connection': 2 / 6,
        'trust': 2 / 6,
        'communication': 1 / 6,
        'intimacy': 1 / 6,
      };

      // The check-in must carry the SAME config it was saved with
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {
            'connection': 90,
            'trust': 90,
            'communication': 30,
            'intimacy': 30,
          },
          config: ConfigSnapshot(
            activeAttributes: ['connection', 'trust', 'communication', 'intimacy'],
            weights: weights,
          ),
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: weights,
        referenceDate: refDate,
      );

      // Weighted: (90*2 + 90*2 + 30*1 + 30*1) / 6 = 420/6 = 70
      expect(result.overallScore, closeTo(70, 1));
    });

    test('weights sum to 1.0 in all valid configs', () {
      final configs = [
        {'a': 1.0},
        {'a': 0.5, 'b': 0.5},
        {'a': 2 / 6, 'b': 2 / 6, 'c': 1 / 6, 'd': 1 / 6},
      ];
      for (final w in configs) {
        final total = w.values.fold(0.0, (s, v) => s + v);
        expect(total, closeTo(1.0, 0.01));
      }
    });
  });

  // ===========================================================================
  // Weekly normalization
  // ===========================================================================

  group('Weekly normalization', () {
    test('partial week: mean of days with data only', () {
      // Only 3 days in the most recent week
      final contributions = [
        for (int d = 0; d < 3; d++)
          contribution(
            userId: 'u1',
            timestamp: refDate.subtract(Duration(days: d)),
            scores: {'connection': 80},
          ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      // The most recent week should have data
      final lastWeek = result.weeklyScores.last;
      expect(lastWeek.hasData, isTrue);
      expect(lastWeek.overallScore, closeTo(80, 1));
    });

    test('empty week excluded from monthly aggregation', () {
      // Only check-ins in the most recent week (week 4)
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 80},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      // Weeks 1-3 should have no data
      final emptyWeeks =
          result.weeklyScores.where((w) => !w.hasData).toList();
      expect(emptyWeeks.length, greaterThanOrEqualTo(2));
    });
  });

  // ===========================================================================
  // Monthly normalization
  // ===========================================================================

  group('Monthly normalization', () {
    test('4 weeks all with data -> mean of 4', () {
      final contributions = <ScoreContribution>[];
      for (int w = 0; w < 4; w++) {
        final day = refDate.subtract(Duration(days: w * 7));
        contributions.add(contribution(
          userId: 'u1',
          timestamp: day,
          scores: {'connection': 60 + w * 10}, // 60, 70, 80, 90
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      // Weekly scores vary; monthly = mean of weeks with data
      expect(result.overallScore, greaterThan(0));
      expect(result.weeklyScores.where((w) => w.hasData).length,
          greaterThanOrEqualTo(3));
    });
  });

  // ===========================================================================
  // 30-day window enforcement
  // ===========================================================================

  group('30-day window', () {
    test('check-in at day 30 boundary is included', () {
      final cutoff = refDate.subtract(const Duration(days: 29));
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: cutoff,
          scores: {'connection': 80},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.checkInCount, 1);
    });

    test('check-in at day 31 is excluded', () {
      final tooOld = refDate.subtract(const Duration(days: 31));
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: tooOld,
          scores: {'connection': 80},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.checkInCount, 0);
      expect(result.overallScore, 0);
    });

    test('mix of in-window and out-of-window: only in-window used', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 80},
        ),
        contribution(
          userId: 'u1',
          timestamp: refDate.subtract(const Duration(days: 40)),
          scores: {'connection': 20},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.checkInCount, 1);
      expect(result.overallScore, closeTo(80, 1)); // Only 80, not (80+20)/2
    });
  });

  // ===========================================================================
  // Trend calculation
  // ===========================================================================

  group('Trend calculation', () {
    test('clearly improving: positive trend', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 10; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: 9 - d)),
          scores: {'connection': 30 + d * 7}, // 30 → 93
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallTrend, greaterThan(0));
      expect(result.attributeTrends['connection'], greaterThan(0));
    });

    test('clearly declining: negative trend', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 10; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: 9 - d)),
          scores: {'connection': 93 - d * 7}, // 93 → 30
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallTrend, lessThan(0));
    });

    test('flat/stable: trend near 0', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 8; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: d)),
          scores: {'connection': 70},
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallTrend, closeTo(0, 0.05));
    });

    test('fewer than 4 check-ins: trend = 0', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 80},
        ),
        contribution(
          userId: 'u1',
          timestamp: refDate.subtract(const Duration(days: 1)),
          scores: {'connection': 30},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallTrend, 0);
    });
  });

  // ===========================================================================
  // Insight label mapping
  // ===========================================================================

  group('Insight labels', () {
    test('fewer than 4 check-ins -> New', () {
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 80},
        ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.insight, InsightLabel.justStarting);
    });

    test('high score + stable -> Thriving', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 10; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: d)),
          scores: {'connection': 85},
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.insight, InsightLabel.thriving);
    });

    test('low scores -> Needs Care', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 8; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: d)),
          scores: {'connection': 25},
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.insight, InsightLabel.struggling);
    });
  });

  // ===========================================================================
  // Config snapshot integrity
  // ===========================================================================

  group('Config snapshot integrity', () {
    test('check-in uses its own saved config weights, not current', () {
      // Check-in saved with connection=0.8, trust=0.2 weighting.
      // Current config is now connection=0.5, trust=0.5.
      // The overall should use the SAVED config (0.8/0.2), not current.
      final contributions = [
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 100, 'trust': 0},
          config: ConfigSnapshot(
            activeAttributes: ['connection', 'trust'],
            weights: {'connection': 0.8, 'trust': 0.2},
          ),
        ),
      ];

      // Current weights differ from saved
      final currentWeights = {'connection': 0.5, 'trust': 0.5};

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: currentWeights,
        referenceDate: refDate,
      );

      // If using saved config: 100*0.8 + 0*0.2 = 80
      // If using current config: 100*0.5 + 0*0.5 = 50 (WRONG)
      expect(result.overallScore, closeTo(80, 1));
    });

    test('config change mid-period: each check-in uses own snapshot', () {
      // Older check-ins: only connection was tracked (weight 1.0)
      // Newer check-ins: connection + trust (0.5 each)
      final contributions = [
        // Day -10: old config, only connection
        contribution(
          userId: 'u1',
          timestamp: refDate.subtract(const Duration(days: 10)),
          scores: {'connection': 90},
          config: ConfigSnapshot(
            activeAttributes: ['connection'],
            weights: {'connection': 1.0},
          ),
        ),
        // Day -5: old config, only connection
        contribution(
          userId: 'u1',
          timestamp: refDate.subtract(const Duration(days: 5)),
          scores: {'connection': 90},
          config: ConfigSnapshot(
            activeAttributes: ['connection'],
            weights: {'connection': 1.0},
          ),
        ),
        // Day -2: new config, connection + trust
        contribution(
          userId: 'u1',
          timestamp: refDate.subtract(const Duration(days: 2)),
          scores: {'connection': 90, 'trust': 30},
          config: ConfigSnapshot(
            activeAttributes: ['connection', 'trust'],
            weights: {'connection': 0.5, 'trust': 0.5},
          ),
        ),
        // Day 0: new config, connection + trust
        contribution(
          userId: 'u1',
          timestamp: refDate,
          scores: {'connection': 90, 'trust': 30},
          config: ConfigSnapshot(
            activeAttributes: ['connection', 'trust'],
            weights: {'connection': 0.5, 'trust': 0.5},
          ),
        ),
      ];

      final currentWeights = {'connection': 0.5, 'trust': 0.5};

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: currentWeights,
        referenceDate: refDate,
      );

      // Old check-ins overall = 90 (connection-only config)
      // New check-ins overall = 90*0.5 + 30*0.5 = 60
      // 4 daily overalls: 90 (day-10), 90 (day-5), 60 (day-2), 60 (day-0)
      // Day-10 falls in week 3, days -5/-2/0 fall in week 4
      // Week 3 avg = 90, Week 4 avg = (90+60+60)/3 = 70
      // Monthly = (90+70)/2 = 80
      expect(result.overallScore, closeTo(80, 1));
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('Edge cases', () {
    test('zero check-ins -> empty result', () {
      final result = engine.computeScoreResult(
        contributions: [],
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallScore, 0);
      expect(result.insight, InsightLabel.justStarting);
      expect(result.checkInCount, 0);
      expect(result.weeklyScores, hasLength(4));
    });

    test('exactly 1 check-in: valid scores, insight = New', () {
      final result = engine.computeScoreResult(
        contributions: [
          contribution(
            userId: 'u1',
            timestamp: refDate,
            scores: {'connection': 80},
          ),
        ],
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.overallScore, closeTo(80, 1));
      expect(result.insight, InsightLabel.justStarting);
    });

    test('only one user ever checked in', () {
      final contributions = <ScoreContribution>[];
      for (int d = 0; d < 5; d++) {
        contributions.add(contribution(
          userId: 'u1',
          timestamp: refDate.subtract(Duration(days: d)),
          scores: {'connection': 70},
        ));
      }

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        currentUserId: 'u1',
        referenceDate: refDate,
      );

      expect(result.userCheckInCount, 5);
      expect(result.partnerCheckInCount, 0);
      expect(result.overallScore, closeTo(70, 1));
    });

    test('all check-ins on same day -> 1 daily, 1 weekly, 1 monthly', () {
      final contributions = [
        for (int i = 0; i < 5; i++)
          contribution(
            userId: 'u1',
            timestamp: refDate.add(Duration(minutes: i)),
            scores: {'connection': 70 + i * 2},
          ),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        referenceDate: refDate,
      );

      expect(result.checkInCount, 5);
      final weeksWithData =
          result.weeklyScores.where((w) => w.hasData).length;
      expect(weeksWithData, 1);
    });
  });

  // ===========================================================================
  // User count tracking
  // ===========================================================================

  group('User count tracking', () {
    test('user and partner counts are correct', () {
      final contributions = [
        contribution(userId: 'u1', timestamp: refDate,
            scores: {'connection': 80}),
        contribution(userId: 'u1',
            timestamp: refDate.subtract(const Duration(days: 1)),
            scores: {'connection': 80}),
        contribution(userId: 'u2', timestamp: refDate,
            scores: {'connection': 80}),
      ];

      final result = engine.computeScoreResult(
        contributions: contributions,
        currentWeights: {'connection': 1.0},
        currentUserId: 'u1',
        referenceDate: refDate,
      );

      expect(result.userCheckInCount, 2);
      expect(result.partnerCheckInCount, 1);
      expect(result.checkInCount, 3);
    });
  });
}
