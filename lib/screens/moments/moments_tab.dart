/// Moments tab — calendar view with planned moment markers and month list.
///
/// Shows a swipeable month calendar at the top with glowing dot/dash markers,
/// and a scrollable list of moments for the visible month below.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/external_calendar.dart';
import '../../models/integration_config.dart';
import '../../models/memory.dart';
import '../../models/moment.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/moment_type_icon.dart';
import '../dashboard/widgets/event_cards.dart';
import '../moment/moment_details_sheet.dart';

/// Moments tab displayed as the second tab in [MainShell].
class MomentsTab extends StatefulWidget {
  const MomentsTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<MomentsTab> createState() => _MomentsTabState();
}

class _MomentsTabState extends State<MomentsTab> {
  // Services
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  final _calendarService = CalendarService();

  // State
  StreamSubscription<List<Moment>>? _momentsSub;
  StreamSubscription<IntegrationConfig>? _integrationSub;
  List<Moment> _allMoments = [];
  bool _isLoading = true;

  // Integration state
  CalendarIntegration? _calendarIntegration;
  List<ExternalCalendar> _externalCalendars = [];
  Set<String> _visibleCalendarIds = {};
  List<ExternalEvent> _externalEvents = [];
  bool _isCalendarCardExpanded = false;
  bool _showExternalEvents = true;

  // Calendar
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  List<Moment> get _monthMoments {
    return _allMoments.where((m) => _momentOverlapsMonth(m, _focusedMonth))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Map<DateTime, List<Moment>> get _momentsByDay {
    final map = <DateTime, List<Moment>>{};
    for (final m in _allMoments) {
      final start = DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
      final end = m.endDate != null
          ? DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day)
          : start;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        map.putIfAbsent(key, () => []).add(m);
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadIntegrationState();
  }

  @override
  void dispose() {
    _momentsSub?.cancel();
    _integrationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadIntegrationState() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    _showExternalEvents = prefs.getBool('show_external_events') ?? true;

    _integrationSub = _firestoreService.watchIntegrationConfig(userId).listen(
      (config) async {
        if (!mounted) return;
        final cal = config.calendar;
        setState(() => _calendarIntegration = cal?.enabled == true ? cal : null);

        if (_calendarIntegration != null && _externalCalendars.isEmpty) {
          await _loadCalendars();
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _loadCalendars() async {
    if (_calendarIntegration == null) return;
    final calendars =
        await _calendarService.listCalendars(_calendarIntegration!);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('visible_calendar_ids');

    setState(() {
      _externalCalendars = calendars;
      _visibleCalendarIds = saved != null
          ? saved.toSet()
          : calendars.map((c) => c.id).toSet();
    });

    if (_visibleCalendarIds.isNotEmpty) {
      await _fetchExternalEvents();
    }
  }

  Future<void> _fetchExternalEvents() async {
    if (_calendarIntegration == null || _visibleCalendarIds.isEmpty) {
      setState(() => _externalEvents = []);
      return;
    }

    final events = await _calendarService.fetchEvents(
      integration: _calendarIntegration!,
      calendarIds: _visibleCalendarIds.toList(),
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    );
    if (!mounted) return;
    setState(() => _externalEvents = events);
  }

  Future<void> _toggleCalendarVisibility(String calendarId, bool visible) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (visible) {
        _visibleCalendarIds.add(calendarId);
      } else {
        _visibleCalendarIds.remove(calendarId);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'visible_calendar_ids',
      _visibleCalendarIds.toList(),
    );

    await _fetchExternalEvents();
  }

  void _subscribe() {
    _momentsSub?.cancel();
    setState(() => _isLoading = true);

    _momentsSub = _firestoreService
        .watchAllMoments(widget.spaceId)
        .listen(
      (moments) {
        if (!mounted) return;
        setState(() {
          _allMoments = moments;
          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error loading moments: $error');
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _showMomentDetails(Moment moment) {
    showMomentDetailsSheet(
      context: context,
      moment: moment,
      spaceId: widget.spaceId,
      onEdit: (field) async {
        final focus = switch (field) {
          MomentEditField.date => 'date',
          MomentEditField.time => 'time',
          MomentEditField.notes => 'notes',
          MomentEditField.general => 'none',
        };
        final result = await context.push<Moment>(
          '/moment/${widget.spaceId}/edit?focus=$focus',
          extra: moment,
        );
        if (result != null && mounted) {
          _showMomentDetails(result);
        }
      },
      onDelete: () async {
        try {
          // Remove from synced calendar
          if (moment.isSyncedToCalendar && _calendarIntegration != null) {
            await _calendarService.deleteCalendarEvents(
              moment: moment,
              integration: _calendarIntegration!,
            );
          }

          // Mark as missed (not physically deleted)
          await _firestoreService.updateMomentStatus(
            spaceId: widget.spaceId,
            momentId: moment.id,
            status: MomentStatus.cancelled,
          );

          final userId = _authService.currentUser?.uid;
          if (userId != null) {
            final profile = await _firestoreService.getUserProfile(userId);
            final userName = profile?['name'] as String? ?? 'Someone';
            await _firestoreService.logMomentMissedActivity(
              spaceId: widget.spaceId,
              userId: userId,
              userName: userName,
              momentId: moment.id,
              momentName: moment.name,
              momentType: moment.type.value,
              rescheduled: false,
            );
          }
        } catch (e) {
          debugPrint('Error cancelling moment: $e');
        }
      },
    );
  }

  void _showExternalEventDetails(ExternalEvent event) {
    final providerLabel = _calendarIntegration?.provider == CalendarProvider.google
        ? 'Google Calendar'
        : 'Apple Calendar';
    showMomentDetailsSheet(
      context: context,
      moment: event.toMoment(providerLabel: providerLabel),
      spaceId: widget.spaceId,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
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

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -200 &&
            _isCalendarCardExpanded) {
          HapticFeedback.selectionClick();
          setState(() => _isCalendarCardExpanded = false);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            _buildCalendarCard(),
            const SizedBox(height: 12),
            if (_calendarIntegration != null) ...[
              _buildCalendarSyncCard(),
              const SizedBox(height: 12),
            ],
            Expanded(child: _buildMonthMomentsList()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar card
  // ---------------------------------------------------------------------------

  static final _cardDecoration = BoxDecoration(
    color: AppColors.darkCardLight,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.warmMuted.withValues(alpha: 0.15),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.accentRed.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Future<void> _toggleExternalEventsVisibility() async {
    HapticFeedback.selectionClick();
    setState(() => _showExternalEvents = !_showExternalEvents);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_external_events', _showExternalEvents);
    if (_showExternalEvents && _externalEvents.isEmpty) {
      await _fetchExternalEvents();
    }
  }

  Widget _buildCalendarSyncCard() {
    final cal = _calendarIntegration!;
    final accountLabel = cal.provider == CalendarProvider.google
        ? cal.email ?? 'Google Calendar'
        : 'Apple Calendar';

    return Container(
      width: double.infinity,
      constraints: _isCalendarCardExpanded
          ? const BoxConstraints(maxHeight: 200)
          : null,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _isCalendarCardExpanded = !_isCalendarCardExpanded,
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'LINKED CALENDAR',
                    style: GoogleFonts.outfit(
                      color: AppColors.accentRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _toggleExternalEventsVisibility();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: AnimatedScale(
                    scale: _showExternalEvents ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _showExternalEvents ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.bolt_rounded,
                        color: _showExternalEvents
                            ? AppColors.accentRed
                            : AppColors.warmMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isCalendarCardExpanded) ...[
            const SizedBox(height: 8),
            Text(
              accountLabel,
              style: GoogleFonts.inter(
                color: AppColors.warmDim,
                fontSize: 12,
              ),
            ),
            if (_externalCalendars.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.warmMuted.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _externalCalendars.length,
                  itemBuilder: (_, i) =>
                      _buildCalendarToggleRow(_externalCalendars[i]),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarToggleRow(ExternalCalendar cal) {
    final isVisible = _visibleCalendarIds.contains(cal.id);
    final dotColor =
        cal.color != null ? Color(cal.color!) : AppColors.warmMuted;

    return GestureDetector(
      onTap: () => _toggleCalendarVisibility(cal.id, !isVisible),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cal.name,
                style: GoogleFonts.inter(
                  color: isVisible ? AppColors.warmLight : AppColors.warmMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.sync_rounded,
              size: 16,
              color: isVisible ? AppColors.accentRed : AppColors.warmMuted,
              shadows: isVisible
                  ? [
                      Shadow(
                        color: AppColors.accentRed.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final byDay = _momentsByDay;

    // Merge moment counts + external event counts per day
    final rawCounts = <DateTime, int>{};
    for (final entry in byDay.entries) {
      rawCounts[entry.key] = entry.value.length;
    }
    if (_showExternalEvents) {
      for (final e in _externalEvents) {
        final key = DateTime(
          e.startDate.year,
          e.startDate.month,
          e.startDate.day,
        );
        rawCounts[key] = (rawCounts[key] ?? 0) + 1;
      }
    }

    // Compute percentile-based alphas
    final alphas = _computePercentileAlphas(rawCounts);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: AppDateCalendar(
        focusedDay: DateTime(_focusedMonth.year, _focusedMonth.month, 1),
        firstDay: DateTime(2024, 1),
        lastDay: DateTime(DateTime.now().year + 3, 12),
        selectedDay: null,
        onDaySelected: (day, _) {
          HapticFeedback.selectionClick();
          final dayMoments = byDay[DateTime(day.year, day.month, day.day)] ?? [];
          _showDaySheet(day, dayMoments);
        },
        onPageChanged: (month) {
          setState(() => _focusedMonth = DateTime(month.year, month.month));
          if (_calendarIntegration != null && _visibleCalendarIds.isNotEmpty) {
            _fetchExternalEvents();
          }
        },
        eventCounts: alphas,
      ),
    );
  }

  /// Computes percentile-based alpha values from raw event counts.
  ///
  /// Top 10% of days (min 1) → 1.0 alpha
  /// 50th–90th percentile    → 0.80 alpha
  /// Below 50th percentile   → 0.60 alpha
  static Map<DateTime, double> _computePercentileAlphas(
    Map<DateTime, int> rawCounts,
  ) {
    if (rawCounts.isEmpty) return {};

    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);

    // Percentiles computed from future/today days only
    final futureValues = rawCounts.entries
        .where((e) => !e.key.isBefore(todayLocal))
        .map((e) => e.value)
        .toList()
      ..sort();

    final int p50;
    final int p90;
    if (futureValues.isNotEmpty) {
      final n = futureValues.length;
      p50 = futureValues[((n - 1) * 0.50).floor()];
      p90 = futureValues[((n - 1) * 0.90).floor()];
    } else {
      p50 = 1;
      p90 = 1;
    }

    return rawCounts.map((day, count) {
      final double alpha;
      if (count >= p90 && p90 > 0) {
        alpha = 1.0;
      } else if (count >= p50 && p50 > 0) {
        alpha = 0.80;
      } else {
        alpha = 0.70;
      }
      return MapEntry(day, alpha);
    });
  }

  // ---------------------------------------------------------------------------
  // Day bottom sheet
  // ---------------------------------------------------------------------------

  void _showDaySheet(DateTime day, List<Moment> dayMoments) {
    final dayKey = DateTime(day.year, day.month, day.day);
    final dayExternal = _showExternalEvents
        ? _externalEvents.where((e) {
            final eDay = DateTime(
              e.startDate.year,
              e.startDate.month,
              e.startDate.day,
            );
            return eDay == dayKey;
          }).toList()
        : <ExternalEvent>[];

    final hasEvents = dayMoments.isNotEmpty || dayExternal.isNotEmpty;

    final items = <Widget>[];
    for (final m in dayMoments) {
      items.add(
        _MomentTile(
          moment: m,
          showDate: false,
          onTap: () {
            Navigator.pop(context);
            _showMomentDetails(m);
          },
        ),
      );
    }
    for (final e in dayExternal) {
      items.add(
        _ExternalEventTile(
          event: e,
          onTap: () {
            Navigator.pop(context);
            _showExternalEventDetails(e);
          },
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: AppColors.pureBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: date + plan button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDayTitle(day),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warmLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.accentRed,
                    ),
                    tooltip: 'Plan a moment',
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/moment/${widget.spaceId}');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Events card or empty state
            if (hasEvents)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.warmMuted.withValues(alpha: 0.15),
                      ),
                      itemBuilder: (_, i) => items[i],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  'No events on this day',
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Month moments list
  // ---------------------------------------------------------------------------

  Widget _buildMonthMomentsList() {
    final moments = _monthMoments;
    final visibleExternal =
        _showExternalEvents ? _externalEvents : <ExternalEvent>[];
    final hasExternalEvents = visibleExternal.isNotEmpty;

    if (moments.isEmpty && !hasExternalEvents) {
      return PlanMomentCard(
        onTap: () => context.push('/moment/${widget.spaceId}'),
      );
    }

    final items = <Widget>[];
    for (int i = 0; i < moments.length; i++) {
      items.add(
        _MomentTile(
          moment: moments[i],
          showDate: true,
          onTap: () => _showMomentDetails(moments[i]),
        ),
      );
    }
    for (int i = 0; i < visibleExternal.length; i++) {
      items.add(_ExternalEventTile(
        event: visibleExternal[i],
        onTap: () => _showExternalEventDetails(visibleExternal[i]),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'THIS MONTH',
            style: GoogleFonts.outfit(
              color: AppColors.accentRed,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: AppColors.warmMuted.withValues(alpha: 0.15),
              ),
              itemBuilder: (_, i) => items[i],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool _momentOverlapsMonth(Moment m, DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final mStart = DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
    final mEnd = m.endDate != null
        ? DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day)
        : mStart;
    return !mEnd.isBefore(monthStart) && !mStart.isAfter(monthEnd);
  }

  static String _formatDayTitle(DateTime day) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
  }
}

// =============================================================================
// Moment tile (reusable within this file)
// =============================================================================

class _MomentTile extends StatefulWidget {
  const _MomentTile({
    required this.moment,
    required this.onTap,
    this.showDate = false,
  });

  final Moment moment;
  final VoidCallback onTap;
  final bool showDate;

  @override
  State<_MomentTile> createState() => _MomentTileState();
}

class _MomentTileState extends State<_MomentTile> {
  bool _isPressed = false;

  String get _subtitle {
    if (widget.showDate) return widget.moment.dateDisplay;
    if (widget.moment.timeSlot != null) return widget.moment.timeSlot!.label;
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
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed ? AppColors.cardVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: _isPressed
                ? Border.all(
                    color: AppColors.accentRed.withValues(alpha: 0.2),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: getMomentTypeIconWidget(
                    widget.moment.type,
                    size: 14,
                    color: AppColors.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.moment.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warmLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.moment.isSyncedToCalendar) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.accentRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentRed.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.warmMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// External event tile (gray styling)
// =============================================================================

class _ExternalEventTile extends StatelessWidget {
  const _ExternalEventTile({required this.event, this.onTap});

  final ExternalEvent event;
  final VoidCallback? onTap;

  String get _subtitle {
    final parts = <String>[];
    if (event.calendarName != null) parts.add(event.calendarName!);
    if (event.isAllDay) {
      parts.add('All day');
    } else if (event.startDate != event.endDate) {
      final h = event.startDate.hour;
      final m = event.startDate.minute;
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      parts.add('$hour${m > 0 ? ':${m.toString().padLeft(2, '0')}' : ''} $period');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.warmMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.event_outlined,
                size: 14,
                color: AppColors.warmMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warmMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.warmMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
