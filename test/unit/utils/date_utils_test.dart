/// Unit tests for AppDateFormat utility.
///
/// Covers: DATE-01 through DATE-06 from the test plan.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/utils/date_utils.dart';

void main() {
  // ===========================================================================
  // AppDateFormat
  // ===========================================================================

  group('AppDateFormat', () {
    // DATE-01
    test('short() returns "Day, Mon DD" format', () {
      // Feb 15, 2026 is a Sunday
      final date = DateTime(2026, 2, 15);
      expect(AppDateFormat.short(date), 'Sun, Feb 15');
    });

    test('short() returns correct format for Monday', () {
      // Feb 16, 2026 is a Monday
      final date = DateTime(2026, 2, 16);
      expect(AppDateFormat.short(date), 'Mon, Feb 16');
    });

    // DATE-02
    test('compact() returns "Mon DD" format', () {
      final date = DateTime(2026, 3, 5);
      expect(AppDateFormat.compact(date), 'Mar 5');
    });

    test('compact() for December 25', () {
      final date = DateTime(2026, 12, 25);
      expect(AppDateFormat.compact(date), 'Dec 25');
    });

    // DATE-03
    test('subtitle() returns "DayFull, Mon DD" format', () {
      // Feb 15, 2026 is a Sunday
      final date = DateTime(2026, 2, 15);
      expect(AppDateFormat.subtitle(date), 'Sunday, Feb 15');
    });

    // DATE-04
    test('dayName() returns full day name', () {
      // Mon = 2026-02-16
      expect(AppDateFormat.dayName(DateTime(2026, 2, 16)), 'Monday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 17)), 'Tuesday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 18)), 'Wednesday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 19)), 'Thursday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 20)), 'Friday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 21)), 'Saturday');
      expect(AppDateFormat.dayName(DateTime(2026, 2, 22)), 'Sunday');
    });

    // DATE-05
    test('all methods handle Jan 1 boundary', () {
      final jan1 = DateTime(2026, 1, 1);
      expect(AppDateFormat.short(jan1), contains('Jan 1'));
      expect(AppDateFormat.compact(jan1), 'Jan 1');
      expect(AppDateFormat.dayName(jan1), 'Thursday');
    });

    test('all methods handle Dec 31 boundary', () {
      final dec31 = DateTime(2026, 12, 31);
      expect(AppDateFormat.short(dec31), contains('Dec 31'));
      expect(AppDateFormat.compact(dec31), 'Dec 31');
      expect(AppDateFormat.dayName(dec31), 'Thursday');
    });

    // DATE-06
    test('all methods handle leap year Feb 29', () {
      // 2028 is a leap year
      final feb29 = DateTime(2028, 2, 29);
      expect(AppDateFormat.short(feb29), contains('Feb 29'));
      expect(AppDateFormat.compact(feb29), 'Feb 29');
      expect(AppDateFormat.dayName(feb29), 'Tuesday');
    });

    test('short covers all months', () {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      for (int i = 1; i <= 12; i++) {
        final date = DateTime(2026, i, 15);
        expect(AppDateFormat.compact(date), contains(months[i - 1]));
      }
    });
  });

  // ===========================================================================
  // toLocalDate — timezone normalization
  // ===========================================================================

  group('AppDateFormat.toLocalDate', () {
    test('converts UTC midnight to local midnight', () {
      final utcDate = DateTime.utc(2026, 3, 10);
      final local = AppDateFormat.toLocalDate(utcDate);
      expect(local.year, 2026);
      expect(local.month, 3);
      expect(local.day, 10);
      expect(local.hour, 0);
      expect(local.minute, 0);
      expect(local.isUtc, false);
    });

    test('strips time from local DateTime', () {
      final withTime = DateTime(2026, 3, 10, 14, 30, 45);
      final stripped = AppDateFormat.toLocalDate(withTime);
      expect(stripped.year, 2026);
      expect(stripped.month, 3);
      expect(stripped.day, 10);
      expect(stripped.hour, 0);
      expect(stripped.minute, 0);
      expect(stripped.second, 0);
    });

    test('preserves date for already-midnight local DateTime', () {
      final midnight = DateTime(2026, 3, 10);
      final result = AppDateFormat.toLocalDate(midnight);
      expect(result, midnight);
    });

    test('handles year boundary', () {
      final utcNewYear = DateTime.utc(2027, 1, 1);
      final local = AppDateFormat.toLocalDate(utcNewYear);
      expect(local.year, 2027);
      expect(local.month, 1);
      expect(local.day, 1);
    });

    test('handles leap year Feb 29', () {
      final utcLeap = DateTime.utc(2028, 2, 29, 23, 59, 59);
      final local = AppDateFormat.toLocalDate(utcLeap);
      expect(local.month, 2);
      expect(local.day, 29);
    });
  });
}
