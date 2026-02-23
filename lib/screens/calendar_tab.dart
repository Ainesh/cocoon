/// Events tab for Cocoon app.
///
/// Displays upcoming moments with week and month view options.
/// Premium neumorphic UI with micro-interactions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/moment.dart';
import '../services/firestore_service.dart';
import '../theme/theme.dart';
import '../widgets/neumorphic_container.dart';

/// View mode for moments display.
enum EventViewMode { week, month }

/// Events tab with week and month views.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final _firestoreService = FirestoreService();
  final _scrollController = ScrollController();

  StreamSubscription<List<Moment>>? _momentsSubscription;
  List<Moment> _moments = [];
  bool _isLoading = true;

  // View mode
  EventViewMode _viewMode = EventViewMode.week;

  // Navigation
  DateTime _weekStart = _getWeekStart(DateTime.now());
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _subscribeToMoments();
  }

  @override
  void dispose() {
    _momentsSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToMoments() {
    _momentsSubscription?.cancel();
    setState(() => _isLoading = true);

    _momentsSubscription = _firestoreService
        .watchUpcomingMoments(widget.spaceId, daysAhead: 60)
        .listen(
          (moments) {
            setState(() {
              _moments = moments;
              _isLoading = false;
            });
          },
          onError: (error) {
            debugPrint('Error loading moments: $error');
            setState(() => _isLoading = false);
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Week Navigation
  // ---------------------------------------------------------------------------

  void _previousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _weekStart = _getWeekStart(DateTime.now());
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    });
  }

  // ---------------------------------------------------------------------------
  // Month Navigation
  // ---------------------------------------------------------------------------

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  // ---------------------------------------------------------------------------
  // Moment Helpers
  // ---------------------------------------------------------------------------

  List<Moment> _getMomentsForDay(DateTime day) {
    return _moments.where((moment) {
      final startDay = DateTime(
        moment.startDate.year,
        moment.startDate.month,
        moment.startDate.day,
      );
      final targetDay = DateTime(day.year, day.month, day.day);

      // Check if moment starts on this day
      if (startDay == targetDay) return true;

      // Check if multi-day moment spans this day
      if (moment.endDate != null) {
        final endDay = DateTime(
          moment.endDate!.year,
          moment.endDate!.month,
          moment.endDate!.day,
        );
        return !targetDay.isBefore(startDay) && !targetDay.isAfter(endDay);
      }

      return false;
    }).toList();
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(DateTime month) {
    return DateTime(month.year, month.month, 1).weekday;
  }

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentRed,
          strokeWidth: 2,
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _subscribeToMoments(),
            color: AppColors.accentRed,
            child: _viewMode == EventViewMode.week
                ? _buildWeekView()
                : _buildMonthView(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        border: Border(
          bottom: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // View mode toggle
          _buildViewModeToggle(),
          const SizedBox(height: 16),
          // Navigation
          _viewMode == EventViewMode.week
              ? _buildWeekNavigation()
              : _buildMonthNavigation(),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ViewModeButton(
              label: 'Week',
              icon: Icons.view_week_rounded,
              isSelected: _viewMode == EventViewMode.week,
              onTap: () => setState(() => _viewMode = EventViewMode.week),
            ),
          ),
          Expanded(
            child: _ViewModeButton(
              label: 'Month',
              icon: Icons.calendar_month_rounded,
              isSelected: _viewMode == EventViewMode.month,
              onTap: () => setState(() => _viewMode = EventViewMode.month),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation() {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final monthFormat = DateFormat('MMM d');
    final isCurrentWeek = _getWeekStart(DateTime.now()) == _weekStart;

    return Row(
      children: [
        _buildNavButton(
          Icons.chevron_left_rounded,
          _previousWeek,
          'Previous week',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${monthFormat.format(_weekStart)} - ${monthFormat.format(weekEnd)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmLight,
                ),
              ),
              if (!isCurrentWeek)
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Go to today'),
                ),
            ],
          ),
        ),
        _buildNavButton(Icons.chevron_right_rounded, _nextWeek, 'Next week'),
      ],
    );
  }

  Widget _buildMonthNavigation() {
    final monthFormat = DateFormat('MMMM yyyy');
    final isCurrentMonth =
        _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    return Row(
      children: [
        _buildNavButton(
          Icons.chevron_left_rounded,
          _previousMonth,
          'Previous month',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                monthFormat.format(_currentMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmLight,
                ),
              ),
              if (!isCurrentMonth)
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('Go to today'),
                ),
            ],
          ),
        ),
        _buildNavButton(Icons.chevron_right_rounded, _nextMonth, 'Next month'),
      ],
    );
  }

  Widget _buildNavButton(
    IconData icon,
    VoidCallback onPressed,
    String tooltip,
  ) {
    return IconButton(
      icon: Icon(icon, color: AppColors.accentRed),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.cardVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Week View
  // ---------------------------------------------------------------------------

  Widget _buildWeekView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = _weekStart.add(Duration(days: index));
        final dayMoments = _getMomentsForDay(day);
        return _buildDayCard(day, dayMoments);
      },
    );
  }

  Widget _buildDayCard(DateTime day, List<Moment> moments) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    final dayFormat = DateFormat('EEEE');
    final dateFormat = DateFormat('MMM d');

    return PremiumCard(
      glowIntensity: isToday ? 1.5 : 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.accentRed.withValues(alpha: 0.15)
                  : AppColors.cardVariant,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(
                      color: AppColors.accentRed.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Text(
                  dayFormat.format(day),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPast && !isToday
                        ? AppColors.warmDim
                        : AppColors.warmLight,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(day),
                  style: TextStyle(fontSize: 14, color: AppColors.warmDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Moments list
          if (moments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                isPast ? 'No moments' : 'No moments planned',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.warmDim,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...moments.map((moment) => _TappableMomentTile(moment: moment)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Month View
  // ---------------------------------------------------------------------------

  Widget _buildMonthView() {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_currentMonth);
    final totalCells = ((daysInMonth + firstWeekday - 1) / 7).ceil() * 7;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          _buildWeekdayHeaders(),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 0.8,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayOffset = index - firstWeekday + 2;
              if (dayOffset < 1 || dayOffset > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayOffset,
              );
              final dayMoments = _getMomentsForDay(day);
              return _buildMonthDayCell(day, dayMoments);
            },
          ),
          const SizedBox(height: 16),
          // Moments list for selected month
          _buildMonthMomentsList(),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warmDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthDayCell(DateTime day, List<Moment> moments) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    final hasMoments = moments.isNotEmpty;

    return GestureDetector(
      onTap: hasMoments ? () => _showDayMomentsSheet(day, moments) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.accentRed.withValues(alpha: 0.2)
              : hasMoments
              ? AppColors.cardVariant
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: AppColors.accentRed, width: 2)
              : hasMoments
              ? Border.all(color: AppColors.accentRed.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isPast && !isToday
                    ? AppColors.warmDim
                    : isToday
                    ? AppColors.accentRed
                    : AppColors.warmLight,
              ),
            ),
            if (hasMoments) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < moments.length.clamp(0, 3); i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (moments.length > 3)
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.accentRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDayMomentsSheet(DateTime day, List<Moment> moments) {
    final dateFormat = DateFormat('EEEE, MMMM d');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_rounded, color: AppColors.accentRed, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dateFormat.format(day),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmLight,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.warmDim),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...moments.map((moment) => _TappableMomentTile(moment: moment)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthMomentsList() {
    // Get all moments for the current month
    final monthMoments = _moments.where((moment) {
      return moment.startDate.year == _currentMonth.year &&
          moment.startDate.month == _currentMonth.month;
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (monthMoments.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No moments this month',
          subtitle: 'Plan a moment from the dashboard to get started.',
        ),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.list_rounded,
            title: 'All Moments',
            trailing: Text(
              '${monthMoments.length} moments',
              style: TextStyle(fontSize: 14, color: AppColors.warmDim),
            ),
          ),
          const SizedBox(height: 12),
          ...monthMoments.map(
            (moment) => _TappableMomentTile(moment: moment, showDate: true),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// View Mode Toggle Button
// ---------------------------------------------------------------------------

class _ViewModeButton extends StatefulWidget {
  const _ViewModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ViewModeButton> createState() => _ViewModeButtonState();
}

class _ViewModeButtonState extends State<_ViewModeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accentRed.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: AppColors.accentRed.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected
                    ? AppColors.accentRed
                    : AppColors.warmDim,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? AppColors.accentRed
                      : AppColors.warmDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable Moment Tile
// ---------------------------------------------------------------------------

class _TappableMomentTile extends StatefulWidget {
  const _TappableMomentTile({required this.moment, this.showDate = false});

  final Moment moment;
  final bool showDate;

  @override
  State<_TappableMomentTile> createState() => _TappableMomentTileState();
}

class _TappableMomentTileState extends State<_TappableMomentTile> {
  bool _isPressed = false;

  String get _timeLabel {
    if (widget.showDate) {
      return widget.moment.dateDisplay;
    }
    if (widget.moment.timeSlot != null) {
      return widget.moment.timeSlot!.label;
    }
    if (widget.moment.type == MomentType.escape && widget.moment.nights > 0) {
      return '${widget.moment.nights} nights';
    }
    return 'All day';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        // TODO: Navigate to moment details
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isPressed ? AppColors.cardVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _isPressed
                ? Border.all(color: AppColors.accentRed.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.moment.type.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.moment.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warmLight,
                      ),
                    ),
                    Text(
                      _timeLabel,
                      style: TextStyle(fontSize: 14, color: AppColors.warmDim),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.accentRed.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
