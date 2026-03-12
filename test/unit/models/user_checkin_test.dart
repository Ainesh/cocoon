/// Unit tests for UserCheckIn model (compact scores format).
///
/// Covers: parsing, round-trip, configSnapshot reconstruction,
/// convenience getters, and utility methods.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/user_checkin.dart';
import 'package:couple_space/scoring/score_models.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ===========================================================================
  // Compact format parsing
  // ===========================================================================

  group('UserCheckIn — compact format', () {
    test('fromJson parses scores and reconstructs configSnapshot', () {
      final ts = DateTime(2026, 2, 20, 10, 30);
      final json = createTestCheckInJson(
        userId: 'user_42',
        timestamp: ts,
        scores: {'connection': 80, 'trust': 75, 'communication': 60},
        notes: 'Great day!',
      );

      final checkIn = UserCheckIn.fromJson('ci_1', json);

      expect(checkIn.id, 'ci_1');
      expect(checkIn.userId, 'user_42');
      expect(checkIn.scores['connection'], 80);
      expect(checkIn.scores['trust'], 75);
      expect(checkIn.scores['communication'], 60);
      expect(checkIn.configSnapshot.activeAttributes, hasLength(3));
      expect(checkIn.notes, 'Great day!');
    });

    test('toJson produces compact format', () {
      final checkIn = createTestCheckIn(
        userId: 'user_1',
        scores: {'connection': 80, 'trust': 75},
        notes: 'Good vibes',
      );

      final json = checkIn.toJson();

      expect(json['userId'], 'user_1');
      expect(json['scores'], isA<Map>());
      final connEntry = (json['scores'] as Map)['connection'] as Map;
      expect(connEntry['value'], 80);
      expect(connEntry['weight'], isA<num>());
      expect(json.containsKey('configSnapshot'), isFalse);
      expect(json['notes'], 'Good vibes');
      expect(json['timestamp'], isA<Timestamp>());
    });

    test('round-trip: toJson then fromJson preserves data', () {
      final original = createTestCheckIn(
        scores: {'connection': 85, 'peace': 90, 'trust': 70},
        notes: 'Test',
      );
      final json = original.toJson();
      final restored = UserCheckIn.fromJson(original.id, json);

      expect(restored.scores, original.scores);
      expect(
        restored.configSnapshot.activeAttributes,
        original.configSnapshot.activeAttributes,
      );
      expect(restored.notes, original.notes);
    });

    test('weights are preserved through round-trip', () {
      final snapshot = ConfigSnapshot(
        activeAttributes: ['connection', 'trust'],
        weights: {'connection': 0.667, 'trust': 0.333},
      );
      final checkIn = createTestCheckIn(
        scores: {'connection': 80, 'trust': 70},
        configSnapshot: snapshot,
      );

      final json = checkIn.toJson();
      final restored = UserCheckIn.fromJson(checkIn.id, json);

      expect(
        restored.configSnapshot.weights['connection'],
        closeTo(0.667, 0.001),
      );
      expect(restored.configSnapshot.weights['trust'], closeTo(0.333, 0.001));
    });
  });

  // ===========================================================================
  // Convenience getters
  // ===========================================================================

  group('UserCheckIn — convenience getters', () {
    test('connection getter reads from scores map', () {
      final checkIn = createTestCheckIn(
        scores: {'connection': 85, 'trust': 70},
      );
      expect(checkIn.connection, 85);
    });

    test('intimacy getter returns 0 when not in scores', () {
      final checkIn = createTestCheckIn(
        scores: {'connection': 85, 'trust': 70},
      );
      expect(checkIn.intimacy, 0);
    });

    test('peace getter reads from scores map', () {
      final checkIn = createTestCheckIn(scores: {'peace': 90});
      expect(checkIn.peace, 90);
    });
  });

  // ===========================================================================
  // Utility methods
  // ===========================================================================

  group('UserCheckIn — utilities', () {
    test('isToday returns true for today\'s timestamp', () {
      final checkIn = createTestCheckIn(timestamp: DateTime.now());
      expect(checkIn.isToday, isTrue);
    });

    test('isToday returns false for yesterday', () {
      final checkIn = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(checkIn.isToday, isFalse);
    });

    test('timeAgo returns "just now" for < 1 minute', () {
      final checkIn = createTestCheckIn(timestamp: DateTime.now());
      expect(checkIn.timeAgo, 'just now');
    });

    test('timeAgo returns correct format for hours, days, weeks', () {
      final hoursAgo = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(hoursAgo.timeAgo, '5h ago');

      final daysAgo = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(daysAgo.timeAgo, '3d ago');

      final yesterday = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(yesterday.timeAgo, 'yesterday');

      final weeksAgo = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(weeksAgo.timeAgo, '2w ago');
    });

    test('copyWith creates correct copy', () {
      final original = createTestCheckIn(
        scores: {'connection': 70, 'trust': 80},
        notes: 'Original',
      );

      final copy = original.copyWith(
        scores: {'connection': 90, 'trust': 80},
        notes: 'Updated',
      );

      expect(copy.scores['connection'], 90);
      expect(copy.notes, 'Updated');
      expect(copy.scores['trust'], 80);
      expect(copy.id, original.id);
    });
  });
}
