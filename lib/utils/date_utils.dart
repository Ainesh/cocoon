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

  /// Normalizes a DateTime to **local midnight** (strips time + UTC flag).
  ///
  /// table_calendar returns UTC midnight dates. Firestore Timestamp stores
  /// UTC internally. If the user is in a negative UTC offset (e.g. UTC-8),
  /// reading back a UTC midnight date converts to the previous day in local
  /// time. This method ensures dates are always stored as local midnight,
  /// preventing day-shift bugs.
  ///
  /// ```dart
  /// final picked = DateTime.utc(2026, 3, 10); // from table_calendar
  /// final safe = AppDateFormat.toLocalDate(picked);
  /// // → DateTime(2026, 3, 10) in local time
  /// ```
  static DateTime toLocalDate(DateTime date) {
    // For UTC dates (from table_calendar), use UTC components to avoid
    // day-shift in negative UTC offset timezones.
    if (date.isUtc) {
      return DateTime(date.year, date.month, date.day);
    }
    // For local dates, just strip time
    return DateTime(date.year, date.month, date.day);
  }
}
