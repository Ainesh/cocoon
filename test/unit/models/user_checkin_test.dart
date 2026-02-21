/// Unit tests for UserCheckIn and CheckInStats models.
///
/// Covers: CHK-01 through CHK-18 from the test plan.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/user_checkin.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ===========================================================================
  // UserCheckIn Model
  // ===========================================================================

  group('UserCheckIn', () {
    // CHK-01
    test('fromJson parses all fields correctly', () {
      final ts = DateTime(2026, 2, 20, 10, 30);
      final json = createTestCheckInJson(
        userId: 'user_42',
        timestamp: ts,
        connection: 8,
        intimacy: 7,
        peace: 9,
        notes: 'Great day!',
      );

      final checkIn = UserCheckIn.fromJson('ci_1', json);

      expect(checkIn.id, 'ci_1');
      expect(checkIn.userId, 'user_42');
      expect(checkIn.connection, 8);
      expect(checkIn.intimacy, 7);
      expect(checkIn.peace, 9);
      expect(checkIn.notes, 'Great day!');
      expect(checkIn.timestamp.year, 2026);
    });

    // CHK-02
    test('fromJson uses peace field when present', () {
      final json = {
        'userId': 'user_1',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'connection': 5,
        'intimacy': 5,
        'peace': 7,
      };

      final checkIn = UserCheckIn.fromJson('ci_1', json);
      expect(checkIn.peace, 7);
    });

    // CHK-03
    test('fromJson converts legacy stress to peace (inverted)', () {
      final json = {
        'userId': 'user_1',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'connection': 5,
        'intimacy': 5,
        'stress': 3, // stress=3 -> peace = 10 - 3 = 7
      };

      final checkIn = UserCheckIn.fromJson('ci_1', json);
      expect(checkIn.peace, 7);
    });

    // CHK-04
    test('fromJson defaults peace to 5 when neither field present', () {
      final json = {
        'userId': 'user_1',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'connection': 5,
        'intimacy': 5,
      };

      final checkIn = UserCheckIn.fromJson('ci_1', json);
      expect(checkIn.peace, 5);
    });

    // CHK-05
    test('fromJson handles null/missing fields with defaults', () {
      final json = <String, dynamic>{
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };

      final checkIn = UserCheckIn.fromJson('ci_1', json);
      expect(checkIn.userId, '');
      expect(checkIn.connection, 5);
      expect(checkIn.intimacy, 5);
      expect(checkIn.peace, 5);
      expect(checkIn.notes, '');
    });

    // CHK-06
    test('toJson produces correct map', () {
      final checkIn = createTestCheckIn(
        userId: 'user_1',
        connection: 8,
        intimacy: 7,
        peace: 9,
        notes: 'Good vibes',
      );

      final json = checkIn.toJson();

      expect(json['userId'], 'user_1');
      expect(json['connection'], 8);
      expect(json['intimacy'], 7);
      expect(json['peace'], 9);
      expect(json['notes'], 'Good vibes');
      expect(json['timestamp'], isA<Timestamp>());
    });

    // CHK-07
    test('isToday returns true for today\'s timestamp', () {
      final checkIn = createTestCheckIn(timestamp: DateTime.now());
      expect(checkIn.isToday, isTrue);
    });

    // CHK-08
    test('isToday returns false for yesterday', () {
      final checkIn = createTestCheckIn(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(checkIn.isToday, isFalse);
    });

    // CHK-09
    test('timeAgo returns "just now" for < 1 minute', () {
      final checkIn = createTestCheckIn(timestamp: DateTime.now());
      expect(checkIn.timeAgo, 'just now');
    });

    // CHK-10
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

    // CHK-11
    test('copyWith creates correct copy', () {
      final original = createTestCheckIn(
        connection: 5,
        intimacy: 6,
        peace: 7,
      );

      final copy = original.copyWith(connection: 9, notes: 'Updated');

      expect(copy.connection, 9);
      expect(copy.notes, 'Updated');
      expect(copy.intimacy, 6); // unchanged
      expect(copy.peace, 7); // unchanged
      expect(copy.id, original.id); // unchanged
    });
  });

  // ===========================================================================
  // CheckInStats
  // ===========================================================================

  group('CheckInStats', () {
    // CHK-12
    test('empty has zero values', () {
      expect(CheckInStats.empty.avgConnection, 0);
      expect(CheckInStats.empty.avgIntimacy, 0);
      expect(CheckInStats.empty.avgPeace, 0);
      expect(CheckInStats.empty.checkInCount, 0);
      expect(CheckInStats.empty.connectionTrend, 0);
      expect(CheckInStats.empty.intimacyTrend, 0);
      expect(CheckInStats.empty.peaceTrend, 0);
    });

    // CHK-13
    test('fromCheckIns returns empty for empty list', () {
      final stats = CheckInStats.fromCheckIns([]);
      expect(stats.avgConnection, 0);
      expect(stats.checkInCount, 0);
    });

    // CHK-14
    test('fromCheckIns calculates averages correctly', () {
      final checkIns = [
        createTestCheckIn(connection: 8, intimacy: 6, peace: 10),
        createTestCheckIn(connection: 4, intimacy: 8, peace: 6),
      ];

      final stats = CheckInStats.fromCheckIns(checkIns);

      expect(stats.avgConnection, 6.0); // (8+4)/2
      expect(stats.avgIntimacy, 7.0); // (6+8)/2
      expect(stats.avgPeace, 8.0); // (10+6)/2
      expect(stats.checkInCount, 2);
    });

    // CHK-15
    test('fromCheckIns calculates trends when >= 4 check-ins', () {
      // Newer check-ins first (sorted by timestamp desc)
      final checkIns = [
        createTestCheckIn(
          id: 'c1',
          connection: 9,
          intimacy: 9,
          peace: 9,
          timestamp: DateTime.now(),
        ),
        createTestCheckIn(
          id: 'c2',
          connection: 8,
          intimacy: 8,
          peace: 8,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        createTestCheckIn(
          id: 'c3',
          connection: 4,
          intimacy: 4,
          peace: 4,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
        createTestCheckIn(
          id: 'c4',
          connection: 3,
          intimacy: 3,
          peace: 3,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      final stats = CheckInStats.fromCheckIns(checkIns);

      // Newer half (c1, c2) avg = 8.5, Older half (c3, c4) avg = 3.5
      // Trend = (8.5 - 3.5) / 10 = 0.5
      expect(stats.connectionTrend, closeTo(0.5, 0.01));
      expect(stats.intimacyTrend, closeTo(0.5, 0.01));
      expect(stats.peaceTrend, closeTo(0.5, 0.01));
    });

    // CHK-16
    test('fromCheckIns does not calculate trends when < 4 check-ins', () {
      final checkIns = [
        createTestCheckIn(id: 'c1', connection: 9),
        createTestCheckIn(id: 'c2', connection: 3),
      ];

      final stats = CheckInStats.fromCheckIns(checkIns);

      expect(stats.connectionTrend, 0);
      expect(stats.intimacyTrend, 0);
      expect(stats.peaceTrend, 0);
    });

    // CHK-17
    test('fromCheckIns separates user vs partner counts', () {
      final checkIns = [
        createTestCheckIn(id: 'c1', userId: 'user_a'),
        createTestCheckIn(id: 'c2', userId: 'user_a'),
        createTestCheckIn(id: 'c3', userId: 'user_b'),
      ];

      final stats = CheckInStats.fromCheckIns(
        checkIns,
        currentUserId: 'user_a',
      );

      expect(stats.userCheckInCount, 2);
      expect(stats.partnerCheckInCount, 1);
    });

    // CHK-18
    test('trend values are clamped to [-1, 1]', () {
      // Extreme difference: newer = all 10s, older = all 1s
      final checkIns = [
        createTestCheckIn(
          id: 'c1',
          connection: 10,
          intimacy: 10,
          peace: 10,
          timestamp: DateTime.now(),
        ),
        createTestCheckIn(
          id: 'c2',
          connection: 10,
          intimacy: 10,
          peace: 10,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        createTestCheckIn(
          id: 'c3',
          connection: 1,
          intimacy: 1,
          peace: 1,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
        createTestCheckIn(
          id: 'c4',
          connection: 1,
          intimacy: 1,
          peace: 1,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      final stats = CheckInStats.fromCheckIns(checkIns);

      expect(stats.connectionTrend, lessThanOrEqualTo(1.0));
      expect(stats.connectionTrend, greaterThanOrEqualTo(-1.0));
      expect(stats.intimacyTrend, lessThanOrEqualTo(1.0));
      expect(stats.intimacyTrend, greaterThanOrEqualTo(-1.0));
      expect(stats.peaceTrend, lessThanOrEqualTo(1.0));
      expect(stats.peaceTrend, greaterThanOrEqualTo(-1.0));
    });
  });
}
