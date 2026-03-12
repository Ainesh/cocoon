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
  bool _isSyncingCalendars = false;
  bool _isCalendarCardExpanded = false;

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

    setState(() => _isSyncingCalendars = true);
    final events = await _calendarService.fetchEvents(
      integration: _calendarIntegration!,
      calendarIds: _visibleCalendarIds.toList(),
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    );
    if (!mounted) return;
    setState(() {
      _externalEvents = events;
      _isSyncingCalendars = false;
    });
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
        .watchUpcomingMoments(widget.spaceId, daysAhead: 365)
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
          await _firestoreService.deleteMoment(
            spaceId: widget.spaceId,
            momentId: moment.id,
          );
          final userId = _authService.currentUser?.uid;
          if (userId != null) {
            final profile = await _firestoreService.getUserProfile(userId);
            final userName = profile?['name'] as String? ?? 'Someone';
            await _firestoreService.logMomentDeletedActivity(
              spaceId: widget.spaceId,
              userId: userId,
              userName: userName,
              momentName: moment.name,
              momentType: moment.type.value,
            );
          }
        } catch (e) {
          debugPrint('Error deleting moment: $e');
        }
      },
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

    return Padding(
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

  Widget _buildCalendarSyncCard() {
    final cal = _calendarIntegration!;
    final accountLabel = cal.provider == CalendarProvider.google
        ? cal.email ?? 'Google Calendar'
        : 'Apple Calendar';
    final calCount = _visibleCalendarIds.length;
    final totalCount = _externalCalendars.length;

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
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                () => _isCalendarCardExpanded = !_isCalendarCardExpanded,
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LINKED CALENDAR',
                        style: GoogleFonts.outfit(
                          color: AppColors.warmMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$accountLabel · $calCount/$totalCount calendars',
                        style: GoogleFonts.inter(
                          color: AppColors.warmDim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _isSyncingCalendars ? null : () {
                    HapticFeedback.selectionClick();
                    _fetchExternalEvents();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isSyncingCalendars
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentRed,
                            ),
                          )
                        : Icon(
                            Icons.sync_rounded,
                            color: AppColors.accentRed,
                            size: 16,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isCalendarCardExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.warmMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (_isCalendarCardExpanded && _externalCalendars.isNotEmpty) ...[
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
      ),
    );
  }

  Widget _buildCalendarToggleRow(ExternalCalendar cal) {
    final isVisible = _visibleCalendarIds.contains(cal.id);
    final dotColor =
        cal.color != null ? Color(cal.color!) : AppColors.warmMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
          Transform.scale(
            scale: 0.5,
            child: Switch.adaptive(
              value: isVisible,
              onChanged: (v) => _toggleCalendarVisibility(cal.id, v),
              activeColor: AppColors.accentRed,
              activeTrackColor: AppColors.accentRed.withValues(alpha: 0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final byDay = _momentsByDay;
    final rangePositions = _computeRangePositions();

    final markers = <DateTime, Widget>{};
    for (final entry in byDay.entries) {
      final day = entry.key;
      final moments = entry.value;
      final pos = rangePositions[day];

      if (pos != null) {
        markers[day] = _rangeMarker(pos, moments.length);
      } else {
        markers[day] = _dotMarker(moments.length);
      }
    }

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
          final dayMoments = byDay[DateTime(day.year, day.month, day.day)];
          if (dayMoments != null && dayMoments.isNotEmpty) {
            HapticFeedback.selectionClick();
            _showDaySheet(day, dayMoments);
          }
        },
        onPageChanged: (month) {
          setState(() => _focusedMonth = DateTime(month.year, month.month));
          if (_calendarIntegration != null && _visibleCalendarIds.isNotEmpty) {
            _fetchExternalEvents();
          }
        },
        markers: markers,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Range position computation
  // ---------------------------------------------------------------------------

  /// For each day that belongs to a multi-day moment, compute its position
  /// within the range: start, middle, or end.
  Map<DateTime, _RangePos> _computeRangePositions() {
    final map = <DateTime, _RangePos>{};
    for (final m in _allMoments) {
      if (m.endDate == null) continue;
      final start =
          DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
      final end = DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day);
      if (start == end) continue;

      for (var d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        if (d == start) {
          map[key] = _RangePos.start;
        } else if (d == end) {
          map.putIfAbsent(key, () => _RangePos.end);
        } else {
          map.putIfAbsent(key, () => _RangePos.middle);
        }
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------------

  Widget _dotMarker(int count) {
    final clamped = count.clamp(1, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(clamped, (_) {
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
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
        );
      }),
    );
  }

  /// Renders a connected line segment for multi-day moments.
  ///
  /// start  → rounded left cap, extends to right edge
  /// middle → full width, no rounding
  /// end    → extends from left edge, rounded right cap
  Widget _rangeMarker(_RangePos pos, int momentCount) {
    const h = 3.0;

    final borderRadius = switch (pos) {
      _RangePos.start => const BorderRadius.horizontal(
          left: Radius.circular(2),
        ),
      _RangePos.end => const BorderRadius.horizontal(
          right: Radius.circular(2),
        ),
      _RangePos.middle => BorderRadius.zero,
    };

    final alignment = switch (pos) {
      _RangePos.start => Alignment.centerRight,
      _RangePos.end => Alignment.centerLeft,
      _RangePos.middle => Alignment.center,
    };

    final widthFraction = pos == _RangePos.middle ? 1.0 : 0.6;

    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: widthFraction,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: AppColors.accentRed,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Day bottom sheet
  // ---------------------------------------------------------------------------

  void _showDaySheet(DateTime day, List<Moment> moments) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sheetPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_rounded, color: AppColors.accentRed, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _formatDayTitle(day),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmLight,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.warmDim),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...moments.map(
              (m) => _MomentTile(
                moment: m,
                showDate: false,
                onTap: () {
                  Navigator.pop(ctx);
                  _showMomentDetails(m);
                },
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
    final hasExternalEvents = _externalEvents.isNotEmpty;

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
    for (int i = 0; i < _externalEvents.length; i++) {
      items.add(_ExternalEventTile(event: _externalEvents[i]));
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
              color: AppColors.warmMuted,
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
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: getMomentTypeIconWidget(
                    widget.moment.type,
                    size: 20,
                    color: AppColors.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.moment.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warmLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.moment.isSyncedToCalendar) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
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
                        fontSize: 14,
                        color: AppColors.warmDim,
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
  const _ExternalEventTile({required this.event});

  final ExternalEvent event;

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warmMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                Icons.event_outlined,
                size: 20,
                color: AppColors.warmMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warmMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.warmMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Position of a day within a multi-day moment range.
enum _RangePos { start, middle, end }
