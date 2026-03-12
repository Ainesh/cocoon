/// Unit tests for Moments tab helper logic.
///
/// Covers the month-overlap filter used to display moments for a given month.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/moment.dart';
import '../../helpers/test_helpers.dart';

/// Mirrors the static helper in `_MomentsTabState`.
bool momentOverlapsMonth(Moment m, DateTime month) {
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  final mStart =
      DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
  final mEnd = m.endDate != null
      ? DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day)
      : mStart;
  return !mEnd.isBefore(monthStart) && !mStart.isAfter(monthEnd);
}

void main() {
  group('momentOverlapsMonth', () {
    final march2026 = DateTime(2026, 3);

    test('single-day moment inside month returns true', () {
      final m = createTestMoment(
        startDate: DateTime.utc(2026, 3, 15),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('single-day moment on first day of month returns true', () {
      final m = createTestMoment(
        startDate: DateTime.utc(2026, 3, 1),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('single-day moment on last day of month returns true', () {
      final m = createTestMoment(
        startDate: DateTime.utc(2026, 3, 31),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('single-day moment in different month returns false', () {
      final m = createTestMoment(
        startDate: DateTime.utc(2026, 4, 1),
      );
      expect(momentOverlapsMonth(m, march2026), isFalse);
    });

    test('single-day moment before month returns false', () {
      final m = createTestMoment(
        startDate: DateTime.utc(2026, 2, 28),
      );
      expect(momentOverlapsMonth(m, march2026), isFalse);
    });

    test('multi-day moment fully inside month returns true', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 3, 10),
        endDate: DateTime.utc(2026, 3, 15),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('multi-day moment spanning into month from previous returns true', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 2, 25),
        endDate: DateTime.utc(2026, 3, 5),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('multi-day moment spanning out of month to next returns true', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 3, 28),
        endDate: DateTime.utc(2026, 4, 3),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('multi-day moment entirely before month returns false', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 2, 10),
        endDate: DateTime.utc(2026, 2, 20),
      );
      expect(momentOverlapsMonth(m, march2026), isFalse);
    });

    test('multi-day moment entirely after month returns false', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 4, 5),
        endDate: DateTime.utc(2026, 4, 10),
      );
      expect(momentOverlapsMonth(m, march2026), isFalse);
    });

    test('multi-day moment spanning entire month returns true', () {
      final m = createTestEscapeMoment(
        startDate: DateTime.utc(2026, 2, 15),
        endDate: DateTime.utc(2026, 4, 15),
      );
      expect(momentOverlapsMonth(m, march2026), isTrue);
    });

    test('february month end calculated correctly (non-leap year)', () {
      final feb2027 = DateTime(2027, 2);
      final m = createTestMoment(
        startDate: DateTime.utc(2027, 2, 28),
      );
      expect(momentOverlapsMonth(m, feb2027), isTrue);

      final mar1 = createTestMoment(
        startDate: DateTime.utc(2027, 3, 1),
      );
      expect(momentOverlapsMonth(mar1, feb2027), isFalse);
    });
  });
}
