/// Dashboard tab for Cocoon app.
///
/// Modern dark UI with animated health score card featuring circular
/// dotted progress indicators and flip animation for health metrics.
/// Supports live updates for both events and check-ins.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _hasAnimatedOnce = false;

  // Stream subscriptions for live updates
  StreamSubscription<List<SpaceEvent>>? _eventsSubscription;
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  
  List<SpaceEvent> _upcomingEvents = [];
  List<UserCheckIn> _recentCheckIns = [];

  CheckInStats _checkInStats = CheckInStats.empty;
  List<Map<String, dynamic>>? _dailyScores;
  int _streak = 0;

  // Reference to health card for triggering animation
  final GlobalKey<HealthCardState> _healthCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _subscribeToStreams();
    _loadInitialData();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _checkInsSubscription?.cancel();
    super.dispose();
  }

  /// Subscribe to live streams for events and check-ins.
  void _subscribeToStreams() {
    final currentUserId = _authService.currentUser?.uid;
    
    // Subscribe to events
    _eventsSubscription = _firestoreService
        .watchUpcomingEvents(widget.spaceId, daysAhead: 30)
        .listen((events) {
      if (mounted) setState(() => _upcomingEvents = events);
    });

    // Subscribe to check-ins for live health score updates
    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen((checkIns) {
      if (mounted) {
        final oldCount = _recentCheckIns.length;
        _recentCheckIns = checkIns;
        
        // Recalculate stats from the new check-ins
        _checkInStats = CheckInStats.fromCheckIns(checkIns, currentUserId: currentUserId);
        
        setState(() {});
        
        // If this is a new check-in (count increased), animate the health card
        if (checkIns.length > oldCount && _hasAnimatedOnce) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _healthCardKey.currentState?.animateHealthScore(forceReanimate: true);
            }
          });
        }
      }
    });
  }

  /// Load initial data that isn't streamed (daily scores, streak).
  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _firestoreService.getDailyHealthScores(widget.spaceId, days: 30),
        _firestoreService.getCheckInStreak(widget.spaceId),
      ]);

      if (mounted) {
        setState(() {
          _dailyScores = (results[0] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _streak = results[1] as int? ?? 0;
          _isLoading = false;
        });
        
        // Animate health score on first load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAnimatedOnce) {
            _hasAnimatedOnce = true;
            _healthCardKey.currentState?.animateHealthScore();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    // Haptic feedback when refresh is triggered
    HapticFeedback.mediumImpact();
    
    try {
      // Reload daily scores and streak
      final results = await Future.wait([
        _firestoreService.getDailyHealthScores(widget.spaceId, days: 30),
        _firestoreService.getCheckInStreak(widget.spaceId),
      ]);

      if (mounted) {
        setState(() {
          _dailyScores = (results[0] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _streak = results[1] as int? ?? 0;
        });
        
        // Re-animate health score on refresh
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _healthCardKey.currentState?.animateHealthScore(forceReanimate: true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing dashboard: $e');
    }
    
    // Haptic feedback when refresh completes
    if (mounted) HapticFeedback.lightImpact();
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
      onRefresh: _handleRefresh,
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
