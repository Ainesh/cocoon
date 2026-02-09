/// Dashboard tab for Cocoon app.
///
/// Modern dark UI with animated health score card featuring circular
/// dotted progress indicators. Shows upcoming moments and quick actions.
/// Supports live updates for both moments and check-ins.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/moment.dart';
import '../../models/user_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../../models/activity.dart';
import '../moment/moment_details_sheet.dart';
import 'widgets/activity_trail.dart';
import 'widgets/event_cards.dart';
import 'widgets/health_card.dart';
import 'widgets/health_details_sheet.dart';

/// Dashboard tab widget.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _hasAnimatedOnce = false;

  // Stream subscriptions for live updates
  StreamSubscription<List<Moment>>? _momentsSubscription;
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  
  List<Moment> _upcomingMoments = [];
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
    _momentsSubscription?.cancel();
    _checkInsSubscription?.cancel();
    super.dispose();
  }

  /// Subscribe to live streams for moments and check-ins.
  void _subscribeToStreams() {
    final currentUserId = _authService.currentUser?.uid;
    
    // Subscribe to moments
    _momentsSubscription = _firestoreService
        .watchUpcomingMoments(widget.spaceId, daysAhead: 60)
        .listen((moments) {
      if (mounted) setState(() => _upcomingMoments = moments);
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

  void _showMomentDetails(Moment moment) {
    showMomentDetailsSheet(
      context: context,
      moment: moment,
      onEdit: (field) async {
        // Map MomentEditField to EditMomentFocus
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
        // If edit returned an updated moment, re-open MDS with it
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
          
          // Log activity
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
          
          if (mounted) {
            HapticFeedback.mediumImpact();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete moment: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
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
            const SizedBox(height: 24),
            _buildActivityTrail(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainGrid() {
    // Layout: ComingUp card takes natural size, PlanMoment fills remaining space
    // When 3+ moments: ComingUp expands (has "+ X moments" text), PlanMoment is fixed
    final momentCount = _upcomingMoments.length;
    final bool hasManyMoments = momentCount >= 3;
    
    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column - Coming Up + Plan a Moment
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Coming Up card - takes natural size when < 2 moments, expands when 2+
                if (hasManyMoments)
                  Expanded(
                    child: ComingUpCard(
                      moments: _upcomingMoments,
                      onMomentTap: (moment) => _showMomentDetails(moment),
                    ),
                  )
                else
                  ComingUpCard(
                    moments: _upcomingMoments,
                    onMomentTap: (moment) => _showMomentDetails(moment),
                  ),
                const SizedBox(height: 12),
                // Plan a Moment button - expands to fill remaining space when < 2 moments
                if (!hasManyMoments)
                  Expanded(
                    child: PlanMomentCard(
                      onTap: () => context.push('/moment/${widget.spaceId}'),
                      expanded: true,
                    ),
                  )
                else
                  PlanMomentCard(
                    onTap: () => context.push('/moment/${widget.spaceId}'),
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

  Widget _buildActivityTrail() {
    return ActivityTrail(
      spaceId: widget.spaceId,
      initialLimit: 6,
      onActivityTap: (activity) => _handleActivityTap(activity),
    );
  }

  void _handleActivityTap(Activity activity) {
    // Navigate to entity based on activity type
    if (!activity.isNavigable) return;

    switch (activity.entityType) {
      case EntityType.moment:
        // Find the moment and show details
        final moment = _upcomingMoments.where((m) => m.id == activity.entityId).firstOrNull;
        if (moment != null) {
          _showMomentDetails(moment);
        }
        break;
      case EntityType.checkin:
        // Navigate to check-ins tab or show check-in details
        // For now, just navigate to check-in screen
        context.push('/checkin/${widget.spaceId}');
        break;
      case EntityType.space:
      case null:
        // No specific navigation for space activities
        break;
    }
  }
}
