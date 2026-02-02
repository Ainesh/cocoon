/// Dashboard tab for Cocoon app.
///
/// Modern dark UI with animated health score card featuring circular
/// dotted progress indicators and flip animation for health metrics.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/space_event.dart';
import '../../models/user_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import 'widgets/event_cards.dart';
import 'widgets/event_creation_sheet.dart';
import 'widgets/health_card.dart';
import 'widgets/health_details_sheet.dart';

/// Dashboard tab widget.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.spaceId});

  final String spaceId;

  /// Shows the event creation bottom sheet.
  void showCreateEventSheet(BuildContext context, String spaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EventCreationSheet(
        spaceId: spaceId,
        firestoreService: FirestoreService(),
        authService: AuthService(),
      ),
    );
  }

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  bool _isLoading = true;

  StreamSubscription<List<SpaceEvent>>? _eventsSubscription;
  List<SpaceEvent> _upcomingEvents = [];

  CheckInStats _checkInStats = CheckInStats.empty;
  List<Map<String, dynamic>>? _dailyScores;
  int _streak = 0;

  // Reference to health card for triggering animation
  final GlobalKey<HealthCardState> _healthCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      final results = await Future.wait([
        _firestoreService.getSpaceCheckInStats(
          widget.spaceId,
          currentUserId: currentUserId,
        ),
        _firestoreService.getDailyHealthScores(widget.spaceId, days: 7),
        _firestoreService.getCheckInStreak(widget.spaceId),
      ]);

      if (mounted) {
        setState(() {
          _checkInStats = results[0] as CheckInStats;
          _dailyScores = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _streak = results[2] as int? ?? 0;
          _isLoading = false;
        });
        // Animate health score after data loads
        _healthCardKey.currentState?.animateHealthScore();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }

    // Subscribe to events
    _eventsSubscription = _firestoreService
        .watchUpcomingEvents(widget.spaceId, daysAhead: 30)
        .listen((events) {
      if (mounted) setState(() => _upcomingEvents = events);
    });
  }

  void _showHealthDetails() {
    showHealthDetailsSheet(
      context: context,
      checkInStats: _checkInStats,
      streak: _streak,
      dailyScores: _dailyScores,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.accentRed));
    }

    return RefreshIndicator(
      color: AppColors.accentRed,
      backgroundColor: AppColors.darkCard,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainGrid(),
            const SizedBox(height: 20),
            _buildUpcomingEvents(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMainGrid() {
    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column - Event cards
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: EventCard(
                    events: _upcomingEvents,
                    index: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: EventCard(
                    events: _upcomingEvents,
                    index: 1,
                    onAddEvent: () => widget.showCreateEventSheet(context, widget.spaceId),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right column - Health card + Check-in
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: HealthCard(
                    key: _healthCardKey,
                    checkInStats: _checkInStats,
                    onTap: _showHealthDetails,
                  ),
                ),
                const SizedBox(height: 12),
                CheckInCard(
                  onTap: () => context.push('/checkin/${widget.spaceId}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    if (_upcomingEvents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'UPCOMING',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        ..._upcomingEvents.take(3).map((event) => UpcomingEventItem(event: event)),
      ],
    );
  }
}
