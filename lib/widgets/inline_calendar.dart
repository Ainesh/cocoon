/// Themed inline calendar widgets for Cocoon app.
///
/// Wraps `table_calendar` with the app's dark theme styling.
/// Two modes: single date selection and range selection.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

// =============================================================================
// Single date calendar
// =============================================================================

/// Inline single-date calendar with Cocoon theme.
///
/// Selected day uses a rounded rectangle; today is bold with no background.
class InlineDateCalendar extends StatelessWidget {
  const InlineDateCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.selectedDay,
    this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay)? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return TableCalendar(
      firstDay: now,
      lastDay: now.add(const Duration(days: 365 * 2)),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) =>
          selectedDay != null && isSameDay(selectedDay, day),
      onDaySelected: (selected, focused) {
        HapticFeedback.selectionClick();
        // Normalize to UTC midnight — all dates stored as UTC
        onDaySelected(AppDateFormat.toUtcDate(selected), focused);
      },
      onPageChanged: onPageChanged,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: _headerStyle,
      daysOfWeekStyle: _daysOfWeekStyle,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.all(2),
        defaultTextStyle: _dayText,
        weekendTextStyle: _dayText,
        todayDecoration: const BoxDecoration(),
        todayTextStyle: _dayText,
        selectedDecoration: const BoxDecoration(),
        selectedTextStyle: _dayText,
        disabledTextStyle: _disabledText,
      ),
      calendarBuilders: CalendarBuilders(
        todayBuilder: (_, day, _) => _todayCell(day),
        selectedBuilder: (_, day, _) => _selectedCell(day),
      ),
      rowHeight: 40,
    );
  }
}

// =============================================================================
// Range date calendar
// =============================================================================

/// Inline range-date calendar with Cocoon theme.
///
/// Start/end use circles that align with the solid red highlight bar.
class InlineRangeCalendar extends StatelessWidget {
  const InlineRangeCalendar({
    super.key,
    required this.focusedDay,
    required this.onRangeSelected,
    this.rangeStartDay,
    this.rangeEndDay,
    this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime? rangeStartDay;
  final DateTime? rangeEndDay;
  final void Function(DateTime? start, DateTime? end, DateTime focusedDay)
  onRangeSelected;
  final void Function(DateTime focusedDay)? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return TableCalendar(
      firstDay: now,
      lastDay: now.add(const Duration(days: 365 * 2)),
      focusedDay: focusedDay,
      rangeStartDay: rangeStartDay,
      rangeEndDay: rangeEndDay,
      rangeSelectionMode: RangeSelectionMode.enforced,
      onRangeSelected: (start, end, focused) {
        HapticFeedback.selectionClick();
        // Normalize to UTC midnight — all dates stored as UTC
        onRangeSelected(
          start != null ? AppDateFormat.toUtcDate(start) : null,
          end != null ? AppDateFormat.toUtcDate(end) : null,
          focused,
        );
      },
      onPageChanged: onPageChanged,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: _headerStyle,
      daysOfWeekStyle: _daysOfWeekStyle,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.all(2),
        defaultTextStyle: _dayText,
        weekendTextStyle: _dayText,
        todayDecoration: const BoxDecoration(),
        todayTextStyle: _dayText,
        rangeStartDecoration: BoxDecoration(
          color: AppColors.accentRed,
          shape: BoxShape.circle,
        ),
        rangeStartTextStyle: _rangeEndpointText,
        rangeEndDecoration: BoxDecoration(
          color: AppColors.accentRed,
          shape: BoxShape.circle,
        ),
        rangeEndTextStyle: _rangeEndpointText,
        rangeHighlightColor: AppColors.accentRed,
        withinRangeTextStyle: _rangeEndpointText,
        disabledTextStyle: _disabledText,
      ),
      calendarBuilders: CalendarBuilders(
        todayBuilder: (_, day, _) => _todayCell(day),
      ),
      rowHeight: 40,
    );
  }
}

// =============================================================================
// Shared theme constants
// =============================================================================

final _headerStyle = HeaderStyle(
  formatButtonVisible: false,
  titleCentered: true,
  titleTextStyle: GoogleFonts.outfit(
    color: AppColors.warmDim,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  leftChevronIcon: Icon(
    Icons.chevron_left_rounded,
    color: AppColors.warmMuted,
    size: 20,
  ),
  rightChevronIcon: Icon(
    Icons.chevron_right_rounded,
    color: AppColors.warmMuted,
    size: 20,
  ),
  headerPadding: const EdgeInsets.only(bottom: 8),
);

final _daysOfWeekStyle = DaysOfWeekStyle(
  weekdayStyle: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 11),
  weekendStyle: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 11),
);

final _dayText = GoogleFonts.outfit(color: AppColors.warmDim, fontSize: 13);

final _disabledText = GoogleFonts.outfit(
  color: AppColors.warmMuted.withValues(alpha: 0.3),
  fontSize: 13,
);

final _rangeEndpointText = GoogleFonts.outfit(
  color: AppColors.pureBlack,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

/// Rounded rectangle cell for selected day.
Widget _selectedCell(DateTime day) {
  return Container(
    margin: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.accentRed,
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      '${day.day}',
      style: GoogleFonts.outfit(
        color: AppColors.pureBlack,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Today cell — same color as other dates but bold, no background.
Widget _todayCell(DateTime day) {
  return Container(
    margin: const EdgeInsets.all(3),
    alignment: Alignment.center,
    child: Text(
      '${day.day}',
      style: GoogleFonts.outfit(
        color: AppColors.warmDim,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
