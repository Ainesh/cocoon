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

import '../../models/moment.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/neumorphic_container.dart';
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

  // State
  StreamSubscription<List<Moment>>? _momentsSub;
  List<Moment> _allMoments = [];
  bool _isLoading = true;

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
  }

  @override
  void dispose() {
    _momentsSub?.cancel();
    super.dispose();
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

    return RefreshIndicator(
      onRefresh: () async => _subscribe(),
      color: AppColors.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xxxl,
        ),
        children: [
          _buildCalendarCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildMonthMomentsList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar card
  // ---------------------------------------------------------------------------

  Widget _buildCalendarCard() {
    final byDay = _momentsByDay;

    final markers = <DateTime, Widget>{};
    for (final entry in byDay.entries) {
      final day = entry.key;
      final moments = entry.value;
      final hasMultiDay = moments.any((m) => m.endDate != null);
      markers[day] = hasMultiDay ? _dashMarker() : _dotMarker(moments.length);
    }

    return PremiumCard(
      margin: EdgeInsets.zero,
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
        },
        markers: markers,
      ),
    );
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

  Widget _dashMarker() {
    return Container(
      width: 18,
      height: 3,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: AppColors.accentRed,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.6),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
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

    if (moments.isEmpty) {
      return PremiumCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.sheetPadding),
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No moments this month',
          subtitle: 'Plan a moment from the dashboard to get started.',
        ),
      );
    }

    return PremiumCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.list_rounded,
            title: 'This Month',
            trailing: Text(
              '${moments.length} moment${moments.length == 1 ? '' : 's'}',
              style: AppTypography.bodySmall(color: AppColors.warmDim),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...moments.map(
            (m) => _MomentTile(
              moment: m,
              showDate: true,
              onTap: () => _showMomentDetails(m),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: AppColors.accentRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.moment.type.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.moment.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warmLight,
                      ),
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
