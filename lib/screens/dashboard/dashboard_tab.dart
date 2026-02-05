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
import 'package:google_fonts/google_fonts.dart';

import '../../models/moment.dart';
import '../../models/user_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../moment/moment_details_sheet.dart';
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
      onEdit: () {
        // TODO: Navigate to edit screen when implemented
        context.push('/moment/${widget.spaceId}');
      },
      onDelete: () async {
        try {
          await _firestoreService.deleteMoment(
            spaceId: widget.spaceId,
            momentId: moment.id,
          );
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
            const SizedBox(height: 20),
            _buildUpcomingMoments(),
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
          // Left column - Coming Up + Plan a Moment
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Coming Up card
                Expanded(
                  child: ComingUpCard(
                    moments: _upcomingMoments,
                    onMomentTap: (moment) => _showMomentDetails(moment),
                  ),
                ),
                const SizedBox(height: 12),
                // Plan a Moment button
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

  Widget _buildUpcomingMoments() {
    // Filter to moments that are more than a preview (after 2nd one)
    final additionalMoments = _upcomingMoments.length > 2 
        ? _upcomingMoments.skip(2).take(3).toList() 
        : <Moment>[];
    
    if (additionalMoments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'MORE MOMENTS',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        ...additionalMoments.map((moment) => _MomentListItem(moment: moment)),
      ],
    );
  }
}

/// List item for additional upcoming moments.
class _MomentListItem extends StatelessWidget {
  const _MomentListItem({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Type emoji container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                moment.type.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moment.name,
                  style: GoogleFonts.inter(
                    color: AppColors.warmLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSubtitle(),
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: moment.isToday || moment.relativeDate == 'Tomorrow'
                  ? AppColors.accentRed.withValues(alpha: 0.15)
                  : AppColors.darkCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              moment.relativeDate,
              style: GoogleFonts.inter(
                color: moment.isToday || moment.relativeDate == 'Tomorrow'
                    ? AppColors.accentRed
                    : AppColors.warmDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle() {
    if (moment.type == MomentType.connect && moment.timeSlot != null) {
      return moment.timeSlot!.label;
    }
    if (moment.type == MomentType.escape && moment.nights > 0) {
      return '${moment.nights} nights';
    }
    return moment.type.label;
  }
}
