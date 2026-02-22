/// Shared date formatting utilities for Cocoon app.
///
/// Centralises all date formatting so the app uses consistent formats.
/// Import: `import 'package:couple_space/utils/date_utils.dart';`
library;

import 'package:intl/intl.dart';

/// Cocoon app date formatting helpers.
abstract final class AppDateFormat {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _daysFull = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  /// Short date: `Mon, Feb 15`
  static String short(DateTime date) =>
      '${_days[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

  /// Compact date: `Feb 15`
  static String compact(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}';

  /// Subtitle date: `Monday, Feb 15`
  static String subtitle(DateTime date) =>
      DateFormat('EEEE, MMM d').format(date);

  /// Full day name: `Monday`
  static String dayName(DateTime date) => _daysFull[date.weekday - 1];

  // ---------------------------------------------------------------------------
  // UTC date helpers
  // ---------------------------------------------------------------------------

  /// Returns today as UTC midnight. Use for all date comparisons and storage.
  static DateTime todayUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Normalizes any DateTime to **UTC midnight** (strips time, ensures UTC).
  ///
  /// All dates in the app should be stored and compared as UTC midnight.
  /// Local timezone conversion happens only in the UI display layer.
  ///
  /// ```dart
  /// final picked = DateTime(2026, 3, 10, 14, 30); // local with time
  /// final utc = AppDateFormat.toUtcDate(picked);
  /// // → DateTime.utc(2026, 3, 10) — UTC midnight
  /// ```
  static DateTime toUtcDate(DateTime date) {
    if (date.isUtc) {
      return DateTime.utc(date.year, date.month, date.day);
    }
    // For local dates, use local year/month/day but store as UTC
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// @deprecated Use [toUtcDate] instead.
  static DateTime toLocalDate(DateTime date) => toUtcDate(date);
}
