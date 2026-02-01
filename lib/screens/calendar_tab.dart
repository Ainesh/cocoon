/// Events tab for Couple Space app.
///
/// Displays upcoming events with week and month view options.
/// Premium neumorphic UI with micro-interactions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/space_event.dart';
import '../services/firestore_service.dart';
import '../widgets/neumorphic_container.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _dimText = Color(0xFF9CA3AF);
const _cardVariant = Color(0xFF2A2A2A);
const _darkGlass = Color(0xFF1E1E1E);

/// View mode for events display.
enum EventViewMode { week, month }

/// Events tab with week and month views.
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final _firestoreService = FirestoreService();
  final _scrollController = ScrollController();

  StreamSubscription<List<SpaceEvent>>? _eventsSubscription;
  List<SpaceEvent> _events = [];
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
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToEvents() {
    _eventsSubscription?.cancel();
    setState(() => _isLoading = true);

    _eventsSubscription = _firestoreService
        .watchUpcomingEvents(widget.spaceId, daysAhead: 60)
        .listen(
      (events) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error loading events: $error');
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
  // Event Helpers
  // ---------------------------------------------------------------------------

  List<SpaceEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) {
      return event.scheduledAt.year == day.year &&
          event.scheduledAt.month == day.month &&
          event.scheduledAt.day == day.day;
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
      return const Center(
        child: CircularProgressIndicator(color: _refinedRed, strokeWidth: 2),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _subscribeToEvents(),
            color: _refinedRed,
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
        color: _darkGlass,
        border: Border(
          bottom: BorderSide(color: _refinedRed.withValues(alpha: 0.1)),
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
        color: _cardVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
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
        _buildNavButton(Icons.chevron_left_rounded, _previousWeek, 'Previous week'),
        Expanded(
          child: Column(
            children: [
              Text(
                '${monthFormat.format(_weekStart)} - ${monthFormat.format(weekEnd)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _lightText,
                ),
              ),
              if (!isCurrentWeek)
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    foregroundColor: _refinedRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    return Row(
      children: [
        _buildNavButton(Icons.chevron_left_rounded, _previousMonth, 'Previous month'),
        Expanded(
          child: Column(
            children: [
              Text(
                monthFormat.format(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _lightText,
                ),
              ),
              if (!isCurrentMonth)
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    foregroundColor: _refinedRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildNavButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return IconButton(
      icon: Icon(icon, color: _refinedRed),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: _cardVariant,
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
        final dayEvents = _getEventsForDay(day);
        return _buildDayCard(day, dayEvents);
      },
    );
  }

  Widget _buildDayCard(DateTime day, List<SpaceEvent> events) {
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
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
              color: isToday ? _refinedRed.withValues(alpha: 0.15) : _cardVariant,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: _refinedRed.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _refinedRed,
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
                    color: isPast && !isToday ? _dimText : _lightText,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(day),
                  style: const TextStyle(fontSize: 14, color: _dimText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Events list
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                isPast ? 'No events' : 'No events planned',
                style: const TextStyle(
                  fontSize: 14,
                  color: _dimText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...events.map((event) => _TappableEventTile(
                  event: event,
                  timeFormat: DateFormat.jm(),
                )),
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
              final day = DateTime(_currentMonth.year, _currentMonth.month, dayOffset);
              final dayEvents = _getEventsForDay(day);
              return _buildMonthDayCell(day, dayEvents);
            },
          ),
          const SizedBox(height: 16),
          // Events list for selected month
          _buildMonthEventsList(),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _dimText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthDayCell(DateTime day, List<SpaceEvent> events) {
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    final hasEvents = events.isNotEmpty;

    return GestureDetector(
      onTap: hasEvents
          ? () => _showDayEventsSheet(day, events)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isToday
              ? _refinedRed.withValues(alpha: 0.2)
              : hasEvents
                  ? _cardVariant
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: _refinedRed, width: 2)
              : hasEvents
                  ? Border.all(color: _refinedRed.withValues(alpha: 0.3))
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
                    ? _dimText
                    : isToday
                        ? _refinedRed
                        : _lightText,
              ),
            ),
            if (hasEvents) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < events.length.clamp(0, 3); i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _refinedRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (events.length > 3)
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 10,
                        color: _refinedRed,
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

  void _showDayEventsSheet(DateTime day, List<SpaceEvent> events) {
    final dateFormat = DateFormat('EEEE, MMMM d');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGlass,
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
                const Icon(Icons.event_rounded, color: _refinedRed, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dateFormat.format(day),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _lightText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _dimText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...events.map((event) => _TappableEventTile(
                  event: event,
                  timeFormat: DateFormat.jm(),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthEventsList() {
    // Get all events for the current month
    final monthEvents = _events.where((event) {
      return event.scheduledAt.year == _currentMonth.year &&
          event.scheduledAt.month == _currentMonth.month;
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (monthEvents.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No events this month',
          subtitle: 'Tap the + button to add a date night or check-in.',
        ),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.list_rounded,
            title: 'All Events',
            trailing: Text(
              '${monthEvents.length} events',
              style: const TextStyle(fontSize: 14, color: _dimText),
            ),
          ),
          const SizedBox(height: 12),
          ...monthEvents.map((event) => _TappableEventTile(
                event: event,
                timeFormat: DateFormat('MMM d, h:mm a'),
                showDate: true,
              )),
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
                ? _refinedRed.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: _refinedRed.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected ? _refinedRed : _dimText,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? _refinedRed : _dimText,
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
// Tappable Event Tile
// ---------------------------------------------------------------------------

class _TappableEventTile extends StatefulWidget {
  const _TappableEventTile({
    required this.event,
    required this.timeFormat,
    this.showDate = false,
  });

  final SpaceEvent event;
  final DateFormat timeFormat;
  final bool showDate;

  @override
  State<_TappableEventTile> createState() => _TappableEventTileState();
}

class _TappableEventTileState extends State<_TappableEventTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        // TODO: Navigate to event details
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
            color: _isPressed ? _cardVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _isPressed
                ? Border.all(color: _refinedRed.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cardVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _refinedRed.withValues(alpha: 0.2)),
                ),
                child: Text(widget.event.type.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _lightText,
                      ),
                    ),
                    Text(
                      widget.timeFormat.format(widget.event.scheduledAt),
                      style: const TextStyle(fontSize: 14, color: _dimText),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _refinedRed.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
