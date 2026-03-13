/// Custom themed calendar widgets for Cocoon app.
///
/// Two modes: single-date selection and range selection.
/// Built from scratch — no external calendar dependency.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

// =============================================================================
// Single-date calendar
// =============================================================================

/// Inline single-date calendar with Cocoon dark theme.
///
/// Swipe left/right to change months. Tapping a day selects it.
/// Selected day uses a rounded rectangle; today is bold with no background.
/// Past days (before today) are dimmed and non-selectable.
class AppDateCalendar extends StatefulWidget {
  const AppDateCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.selectedDay,
    this.onPageChanged,
    this.firstDay,
    this.lastDay,
    this.eventCounts,
    this.dayBuilder,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay)? onPageChanged;

  /// Earliest selectable month. Defaults to current month.
  final DateTime? firstDay;

  /// Latest selectable month. Defaults to 2 years from now.
  final DateTime? lastDay;

  /// Map of dates to heat-map alpha values (0.0–1.0). Days with a value > 0
  /// get a red-tinted background at that alpha.
  final Map<DateTime, double>? eventCounts;

  /// Optional custom builder for each day cell. When provided, replaces the
  /// default cell but still receives the selection/today state.
  final Widget Function(DateTime day, bool isSelected, bool isToday)?
      dayBuilder;

  @override
  State<AppDateCalendar> createState() => _AppDateCalendarState();
}

class _AppDateCalendarState extends State<AppDateCalendar> {
  late PageController _pageController;
  late DateTime _firstMonth;
  late DateTime _lastMonth;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _initPageRange();
  }

  @override
  void didUpdateWidget(AppDateCalendar old) {
    super.didUpdateWidget(old);
    if (old.focusedDay.year != widget.focusedDay.year ||
        old.focusedDay.month != widget.focusedDay.month) {
      final page = _monthDelta(_firstMonth, widget.focusedDay);
      if (page >= 0 && page != _currentPage) {
        _currentPage = page;
        _pageController.jumpToPage(page);
      }
    }
  }

  void _initPageRange() {
    final now = DateTime.now();
    _firstMonth = widget.firstDay != null
        ? DateTime(widget.firstDay!.year, widget.firstDay!.month)
        : DateTime(now.year, now.month);
    _lastMonth = widget.lastDay != null
        ? DateTime(widget.lastDay!.year, widget.lastDay!.month)
        : DateTime(now.year + 2, now.month);
    _currentPage = _monthDelta(_firstMonth, widget.focusedDay).clamp(
      0,
      _totalPages - 1,
    );
    _pageController = PageController(initialPage: _currentPage);
  }

  int get _totalPages => _monthDelta(_firstMonth, _lastMonth) + 1;

  static int _monthDelta(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + b.month - a.month;

  DateTime _monthForPage(int page) =>
      DateTime(_firstMonth.year, _firstMonth.month + page);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    final month = _monthForPage(page);
    widget.onPageChanged?.call(DateTime(month.year, month.month, 1));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarHeader(
          monthForPage: _monthForPage,
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPrevious: _currentPage > 0
              ? () => _pageController.previousPage(
                    duration: _kPageDuration,
                    curve: Curves.easeOutCubic,
                  )
              : null,
          onNext: _currentPage < _totalPages - 1
              ? () => _pageController.nextPage(
                    duration: _kPageDuration,
                    curve: Curves.easeOutCubic,
                  )
              : null,
        ),
        _WeekdayHeaders(),
        const SizedBox(height: 4),
        SizedBox(
          height: _kRowHeight * 6,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _totalPages,
            itemBuilder: (_, page) {
              final month = _monthForPage(page);
              return _MonthGrid(
                month: month,
                selectedDay: widget.selectedDay,
                onDaySelected: (day) {
                  HapticFeedback.selectionClick();
                  final utc = AppDateFormat.toUtcDate(day);
                  widget.onDaySelected(utc, day);
                },
                eventCounts: widget.eventCounts,
                dayBuilder: widget.dayBuilder,
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Range-date calendar
// =============================================================================

/// Inline range-date calendar with Cocoon dark theme.
///
/// First tap selects range start. Second tap selects range end.
/// Start/end use circles; the range between is highlighted with a red bar.
class AppRangeCalendar extends StatefulWidget {
  const AppRangeCalendar({
    super.key,
    required this.focusedDay,
    required this.onRangeSelected,
    this.rangeStartDay,
    this.rangeEndDay,
    this.onPageChanged,
    this.firstDay,
    this.lastDay,
  });

  final DateTime focusedDay;
  final DateTime? rangeStartDay;
  final DateTime? rangeEndDay;
  final void Function(DateTime? start, DateTime? end, DateTime focusedDay)
      onRangeSelected;
  final void Function(DateTime focusedDay)? onPageChanged;
  final DateTime? firstDay;
  final DateTime? lastDay;

  @override
  State<AppRangeCalendar> createState() => _AppRangeCalendarState();
}

class _AppRangeCalendarState extends State<AppRangeCalendar> {
  late PageController _pageController;
  late DateTime _firstMonth;
  late DateTime _lastMonth;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _initPageRange();
  }

  @override
  void didUpdateWidget(AppRangeCalendar old) {
    super.didUpdateWidget(old);
    if (old.focusedDay.year != widget.focusedDay.year ||
        old.focusedDay.month != widget.focusedDay.month) {
      final page = _monthDelta(_firstMonth, widget.focusedDay);
      if (page >= 0 && page != _currentPage) {
        _currentPage = page;
        _pageController.jumpToPage(page);
      }
    }
  }

  void _initPageRange() {
    final now = DateTime.now();
    _firstMonth = widget.firstDay != null
        ? DateTime(widget.firstDay!.year, widget.firstDay!.month)
        : DateTime(now.year, now.month);
    _lastMonth = widget.lastDay != null
        ? DateTime(widget.lastDay!.year, widget.lastDay!.month)
        : DateTime(now.year + 2, now.month);
    _currentPage = _monthDelta(_firstMonth, widget.focusedDay).clamp(
      0,
      _totalPages - 1,
    );
    _pageController = PageController(initialPage: _currentPage);
  }

  int get _totalPages => _monthDelta(_firstMonth, _lastMonth) + 1;

  static int _monthDelta(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + b.month - a.month;

  DateTime _monthForPage(int page) =>
      DateTime(_firstMonth.year, _firstMonth.month + page);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    final month = _monthForPage(page);
    widget.onPageChanged?.call(DateTime(month.year, month.month, 1));
  }

  void _onDayTapped(DateTime day) {
    HapticFeedback.selectionClick();
    final utc = AppDateFormat.toUtcDate(day);

    if (widget.rangeStartDay != null && widget.rangeEndDay == null) {
      if (utc.isBefore(widget.rangeStartDay!)) {
        widget.onRangeSelected(utc, null, day);
      } else {
        widget.onRangeSelected(widget.rangeStartDay, utc, day);
      }
    } else {
      widget.onRangeSelected(utc, null, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarHeader(
          monthForPage: _monthForPage,
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPrevious: _currentPage > 0
              ? () => _pageController.previousPage(
                    duration: _kPageDuration,
                    curve: Curves.easeOutCubic,
                  )
              : null,
          onNext: _currentPage < _totalPages - 1
              ? () => _pageController.nextPage(
                    duration: _kPageDuration,
                    curve: Curves.easeOutCubic,
                  )
              : null,
        ),
        _WeekdayHeaders(),
        const SizedBox(height: 4),
        SizedBox(
          height: _kRowHeight * 6,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _totalPages,
            itemBuilder: (_, page) {
              final month = _monthForPage(page);
              return _RangeMonthGrid(
                month: month,
                rangeStart: widget.rangeStartDay,
                rangeEnd: widget.rangeEndDay,
                onDayTapped: _onDayTapped,
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared constants
// =============================================================================

const _kRowHeight = 40.0;
const _kPageDuration = Duration(milliseconds: 300);
const _kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// =============================================================================
// Header
// =============================================================================

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthForPage,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  final DateTime Function(int) monthForPage;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final month = monthForPage(currentPage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onPrevious,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left_rounded,
                color: onPrevious != null
                    ? AppColors.warmMuted
                    : AppColors.warmMuted.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: GoogleFonts.outfit(
              color: AppColors.warmDim,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNext,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: onNext != null
                    ? AppColors.warmMuted
                    : AppColors.warmMuted.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Weekday headers
// =============================================================================

class _WeekdayHeaders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kWeekdays
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// =============================================================================
// Single-selection month grid
// =============================================================================

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
    this.eventCounts,
    this.dayBuilder,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final void Function(DateTime day) onDaySelected;
  final Map<DateTime, double>? eventCounts;
  final Widget Function(DateTime day, bool isSelected, bool isToday)?
      dayBuilder;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final offset = firstWeekday - 1; // empty cells before day 1
    final totalCells = ((daysInMonth + offset + 6) ~/ 7) * 7;
    final prevMonth = DateTime(month.year, month.month - 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: _kRowHeight,
      ),
      itemCount: totalCells,
      itemBuilder: (_, index) {
        final dayNum = index - offset + 1;

        // Neighboring month days — dimmed but visible
        if (dayNum < 1 || dayNum > daysInMonth) {
          final displayNum = dayNum < 1
              ? daysInPrevMonth + dayNum
              : dayNum - daysInMonth;
          final neighborDay = dayNum < 1
              ? DateTime(prevMonth.year, prevMonth.month, displayNum)
              : DateTime(month.year, month.month + 1, displayNum);
          return GestureDetector(
            onTap: () => onDaySelected(neighborDay),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Text(
                '$displayNum',
                style: GoogleFonts.outfit(
                  color: AppColors.warmMuted.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          );
        }

        final day = DateTime(month.year, month.month, dayNum);
        final isToday = day == todayLocal;
        final isSelected = selectedDay != null && _isSameDay(selectedDay!, day);
        final isPast = day.isBefore(todayLocal);
        final markerKey = DateTime(month.year, month.month, dayNum);
        final heatAlpha = eventCounts?[markerKey] ?? 0.0;
        final hasEvents = heatAlpha > 0;

        if (dayBuilder != null) {
          return GestureDetector(
            onTap: () => onDaySelected(day),
            behavior: HitTestBehavior.opaque,
            child: dayBuilder!(day, isSelected, isToday),
          );
        }

        if (isSelected) {
          return GestureDetector(
            onTap: () => onDaySelected(day),
            behavior: HitTestBehavior.opaque,
            child: Center(child: _SelectedDayCell(day: day)),
          );
        }

        final dimmedAlpha = isPast ? heatAlpha * 0.4 : heatAlpha;

        return GestureDetector(
          onTap: () => onDaySelected(day),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: hasEvents
                  ? BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: dimmedAlpha),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isPast
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.accentRed.withValues(
                                  alpha: heatAlpha * 0.5,
                                ),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: GoogleFonts.outfit(
                  color: hasEvents
                      ? (isPast
                          ? AppColors.warmLight.withValues(alpha: 0.5)
                          : AppColors.pureBlack)
                      : isPast
                          ? AppColors.warmMuted.withValues(alpha: 0.5)
                          : isToday
                              ? AppColors.warmLight
                              : AppColors.warmLight.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Range-selection month grid
// =============================================================================

class _RangeMonthGrid extends StatelessWidget {
  const _RangeMonthGrid({
    required this.month,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onDayTapped,
  });

  final DateTime month;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final void Function(DateTime day) onDayTapped;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final offset = firstWeekday - 1;
    final totalCells = ((daysInMonth + offset + 6) ~/ 7) * 7;

    final prevMonth = DateTime(month.year, month.month - 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: _kRowHeight,
      ),
      itemCount: totalCells,
      itemBuilder: (_, index) {
        final dayNum = index - offset + 1;

        if (dayNum < 1) {
          final prevDay = daysInPrevMonth + dayNum;
          return Center(
            child: Text(
              '$prevDay',
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted.withValues(alpha: 0.25),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        if (dayNum > daysInMonth) {
          final nextDay = dayNum - daysInMonth;
          return Center(
            child: Text(
              '$nextDay',
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted.withValues(alpha: 0.25),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        final day = DateTime(month.year, month.month, dayNum);
        final dayUtc = AppDateFormat.toUtcDate(day);
        final isToday = day == todayLocal;
        final isPast = day.isBefore(todayLocal);

        final isStart =
            rangeStart != null && _isSameDay(rangeStart!, day);
        final isEnd = rangeEnd != null && _isSameDay(rangeEnd!, day);
        final isInRange = rangeStart != null &&
            rangeEnd != null &&
            dayUtc.isAfter(rangeStart!) &&
            dayUtc.isBefore(rangeEnd!);

        Color? bgColor;
        Color textColor;
        FontWeight fontWeight = FontWeight.w600;
        BoxDecoration? decoration;

        if (isStart || isEnd) {
          decoration = BoxDecoration(
            color: AppColors.accentRed,
            shape: BoxShape.circle,
          );
          textColor = AppColors.pureBlack;
          fontWeight = FontWeight.w700;
        } else if (isInRange) {
          bgColor = AppColors.accentRed.withValues(alpha: 0.25);
          textColor = AppColors.warmLight;
        } else if (isPast) {
          textColor = AppColors.warmMuted.withValues(alpha: 0.5);
        } else {
          textColor = isToday
              ? AppColors.warmLight
              : AppColors.warmLight.withValues(alpha: 0.8);
          if (isToday) fontWeight = FontWeight.w800;
        }

        return GestureDetector(
          onTap: isPast ? null : () => onDayTapped(day),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: bgColor,
            alignment: Alignment.center,
            child: Container(
              width: 32,
              height: 32,
              decoration: decoration,
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Selected day cell (rounded rect)
// =============================================================================

class _SelectedDayCell extends StatelessWidget {
  const _SelectedDayCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 24,
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
}

// =============================================================================
// Helpers
// =============================================================================

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

