/// Dashboard tab for Cocoon app.
///
/// Uses ValueNotifier for localized rebuilds — stream updates only rebuild
/// the specific card that changed, not the entire dashboard.
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
import '../checkin/checkin_details_sheet.dart';
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
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  // ---------------------------------------------------------------------------
  // Localized state — ValueNotifiers prevent full-tree rebuilds
  // ---------------------------------------------------------------------------

  /// Moments list — only ComingUpCard listens.
  final _momentsNotifier = ValueNotifier<List<Moment>>([]);

  /// Check-in stats — only HealthCard listens.
  final _statsNotifier = ValueNotifier<CheckInStats>(CheckInStats.empty);

  // Non-streamed data (loaded once, refreshed on pull)
  List<Map<String, dynamic>>? _dailyScores;
  int _streak = 0;

  // UI state
  bool _isLoading = true;
  bool _hasAnimatedOnce = false;

  // Stream subscriptions
  StreamSubscription<List<Moment>>? _momentsSubscription;
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;

  // Reference to health card for triggering animation
  final GlobalKey<HealthCardState> _healthCardKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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
    _momentsNotifier.dispose();
    _statsNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  /// Subscribe to live streams. Updates flow to ValueNotifiers, not setState.
  void _subscribeToStreams() {
    final currentUserId = _authService.currentUser?.uid;

    // Moments → ValueNotifier (only ComingUpCard rebuilds)
    _momentsSubscription = _firestoreService
        .watchUpcomingMoments(widget.spaceId, daysAhead: 60)
        .listen((moments) {
          if (mounted) _momentsNotifier.value = moments;
        });

    // Check-ins → ValueNotifier (only HealthCard rebuilds)
    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen((checkIns) {
          if (mounted) {
            final oldCount = _statsNotifier.value.checkInCount;
            final stats = CheckInStats.fromCheckIns(
              checkIns,
              currentUserId: currentUserId,
            );
            _statsNotifier.value = stats;

            // Animate health card on new check-in
            if (stats.checkInCount > oldCount && _hasAnimatedOnce) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _healthCardKey.currentState?.animateHealthScore(
                    forceReanimate: true,
                  );
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
        _dailyScores =
            (results[0] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _streak = results[1] as int? ?? 0;
        setState(() => _isLoading = false);

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
    HapticFeedback.mediumImpact();

    try {
      final results = await Future.wait([
        _firestoreService.getDailyHealthScores(widget.spaceId, days: 30),
        _firestoreService.getCheckInStreak(widget.spaceId),
      ]);

      if (mounted) {
        _dailyScores =
            (results[0] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _streak = results[1] as int? ?? 0;

        // Re-animate health score on refresh
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _healthCardKey.currentState?.animateHealthScore(
              forceReanimate: true,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing dashboard: $e');
    }

    if (mounted) HapticFeedback.lightImpact();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Opens a moment or check-in details sheet by entity ID.
  /// Called from notification deep links.
  Future<void> openEntityById({
    required String entityType,
    required String entityId,
  }) async {
    if (entityType == 'moment' && entityId.isNotEmpty) {
      // Try cached first, fall back to Firestore
      final cached = _momentsNotifier.value
          .where((m) => m.id == entityId)
          .firstOrNull;
      if (cached != null) {
        _showMomentDetails(cached);
        return;
      }
      try {
        final moment = await _firestoreService.getMoment(
          spaceId: widget.spaceId,
          momentId: entityId,
        );
        if (moment != null && mounted) {
          _showMomentDetails(moment);
        }
      } catch (e) {
        debugPrint('Error opening moment from notification: $e');
      }
    }
  }

  void _showHealthDetails() {
    showHealthDetailsSheet(
      context: context,
      checkInStats: _statsNotifier.value,
      streak: _streak,
      dailyScores: _dailyScores,
    );
  }

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to cancel: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
    );
  }

  void _handleActivityTap(Activity activity) {
    if (!activity.isNavigable) return;

    switch (activity.entityType) {
      case EntityType.moment:
        _openMomentFromActivity(activity);
        break;
      case EntityType.checkin:
        _showCheckinDetails(activity);
        break;
      case EntityType.space:
      case null:
        break;
    }
  }

  /// Opens moment details for an activity.
  /// Checks cached upcoming moments first, falls back to Firestore fetch.
  Future<void> _openMomentFromActivity(Activity activity) async {
    final entityId = activity.entityId;
    if (entityId == null || entityId.isEmpty) return;

    // Try cached upcoming moments first
    final cached = _momentsNotifier.value
        .where((m) => m.id == entityId)
        .firstOrNull;
    if (cached != null) {
      _showMomentDetails(cached);
      return;
    }

    // Not in cache — fetch from Firestore (past or non-upcoming moment)
    try {
      final doc = await _firestoreService.getMoment(
        spaceId: widget.spaceId,
        momentId: entityId,
      );
      if (doc != null && mounted) {
        _showMomentDetails(doc);
      }
    } catch (e) {
      debugPrint('Error fetching moment for activity: $e');
    }
  }

  void _showCheckinDetails(Activity activity) {
    final currentUserId = _authService.currentUser?.uid;
    final displayName =
        (currentUserId != null && activity.actorId == currentUserId)
        ? 'You'
        : activity.actorName;

    showCheckinDetailsSheet(
      context: context,
      actorName: displayName,
      timestamp: activity.timestamp,
      connection: activity.metadata?['connection'] as int? ?? 5,
      intimacy: activity.metadata?['intimacy'] as int? ?? 5,
      peace: activity.metadata?['peace'] as int? ?? 5,
      notes: activity.metadata?['notes'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accentRed),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentRed,
      backgroundColor: AppColors.darkCard,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainGrid(),
            const SizedBox(height: 12),
            _buildActivityTrail(),
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
          // Left column — Coming Up + Plan a Moment
          Expanded(
            flex: 1,
            child: ValueListenableBuilder<List<Moment>>(
              valueListenable: _momentsNotifier,
              builder: (context, moments, _) {
                final hasManyMoments = moments.length >= 3;
                return Column(
                  children: [
                    if (hasManyMoments)
                      Expanded(
                        child: ComingUpCard(
                          moments: moments,
                          onMomentTap: _showMomentDetails,
                        ),
                      )
                    else
                      ComingUpCard(
                        moments: moments,
                        onMomentTap: _showMomentDetails,
                      ),
                    const SizedBox(height: 12),
                    if (!hasManyMoments)
                      Expanded(
                        child: PlanMomentCard(
                          onTap: () =>
                              context.push('/moment/${widget.spaceId}'),
                          expanded: true,
                        ),
                      )
                    else
                      PlanMomentCard(
                        onTap: () => context.push('/moment/${widget.spaceId}'),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Right column — Health card + Check-in
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<CheckInStats>(
                    valueListenable: _statsNotifier,
                    builder: (context, stats, _) {
                      return RepaintBoundary(
                        child: HealthCard(
                          key: _healthCardKey,
                          checkInStats: stats,
                          onTap: _showHealthDetails,
                        ),
                      );
                    },
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
    return RepaintBoundary(
      child: ActivityTrail(
        spaceId: widget.spaceId,
        initialLimit: 6,
        onActivityTap: _handleActivityTap,
      ),
    );
  }
}
