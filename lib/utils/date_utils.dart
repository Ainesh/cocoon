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
}
