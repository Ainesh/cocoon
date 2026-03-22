/// Dashboard tab for Kairos app.
///
/// Uses ValueNotifier for localized rebuilds — stream updates only rebuild
/// the specific card that changed, not the entire dashboard.
///
/// Supports solo mode: when only one member exists, the HealthCard is
/// replaced with a PersonalTrendCard and an InvitePartnerCard is shown.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/memory.dart';
import '../../models/moment.dart';
import '../../models/pulse_config.dart';
import '../../models/user_checkin.dart';
import '../../scoring/checkin_score_source.dart';
import '../../scoring/score_engine.dart';
import '../../scoring/score_models.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../../widgets/moment_type_icon.dart';
import '../../models/activity.dart';
import '../checkin/checkin_details_sheet.dart';
import '../moment/moment_details_sheet.dart';
import 'widgets/activity_trail.dart';
import 'widgets/event_cards.dart';
import 'widgets/health_card.dart';
import 'widgets/health_details_sheet.dart';
import 'widgets/memory_prompt_card.dart';
import 'widgets/personal_trend_card.dart';

const _kInviteCardDismissedKey = 'invite_card_dismissed';

/// Dashboard tab widget.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _scoreEngine = const ScoreEngine();

  // ---------------------------------------------------------------------------
  // Localized state — ValueNotifiers prevent full-tree rebuilds
  // ---------------------------------------------------------------------------

  /// Moments list — only ComingUpCard listens.
  final _momentsNotifier = ValueNotifier<List<Moment>>([]);

  /// ScoreResult — only HealthCard listens.
  final _scoreNotifier = ValueNotifier<ScoreResult>(ScoreResult.empty);

  // Pulse config
  PulseConfig _pulseConfig = PulseConfig.defaultConfig();

  // Non-streamed data
  int _streak = 0;
  int _memberCount = 0;
  bool _inviteCardDismissed = false;
  String? _inviteCode;

  // Prompt state
  Moment? _promptMoment;
  Moment? _livedMoment;

  // UI state
  bool _isLoading = true;
  bool _hasAnimatedOnce = false;

  // Stream subscriptions
  StreamSubscription<List<Moment>>? _momentsSubscription;
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  StreamSubscription<PulseConfig>? _configSubscription;

  // Reference to health card for triggering animation
  final GlobalKey<HealthCardState> _healthCardKey = GlobalKey();

  // Cache check-ins for recomputation when config changes
  List<UserCheckIn> _cachedCheckIns = [];

  // Streak badge animation
  late final AnimationController _streakPulseController;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  bool get _isSoloMode => _memberCount == 1;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _streakPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subscribeToStreams();
    _loadInitialData();
    _loadPromptMoment();
    _loadInviteCardState();
  }

  @override
  void dispose() {
    _momentsSubscription?.cancel();
    _checkInsSubscription?.cancel();
    _configSubscription?.cancel();
    _momentsNotifier.dispose();
    _scoreNotifier.dispose();
    _streakPulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  void _subscribeToStreams() {
    // Moments → ValueNotifier (only ComingUpCard rebuilds)
    _momentsSubscription = _firestoreService
        .watchUpcomingMoments(widget.spaceId, daysAhead: 60)
        .listen((moments) {
          if (mounted) _momentsNotifier.value = moments;
        });

    // Pulse config → recompute scores when config changes
    _configSubscription = _firestoreService
        .watchPulseConfig(widget.spaceId)
        .listen((config) {
      if (mounted) {
        _pulseConfig = config;
        _recomputeScores();
      }
    });

    // Check-ins → compute ScoreResult via engine
    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen((checkIns) {
          if (mounted) {
            final oldCount = _scoreNotifier.value.checkInCount;
            _cachedCheckIns = checkIns;
            _recomputeScores();

            // Animate health card on new check-in
            final newCount = _scoreNotifier.value.checkInCount;
            if (newCount > oldCount && _hasAnimatedOnce) {
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

  /// Recompute the ScoreResult from cached check-ins + current config.
  void _recomputeScores() {
    final currentUserId = _authService.currentUser?.uid;
    final source = CheckInScoreSource(_cachedCheckIns);
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    final contributions = source.getContributions(
      from: cutoff,
      to: now.add(const Duration(days: 1)),
    );

    final result = _scoreEngine.computeScoreResult(
      contributions: contributions,
      currentWeights: _pulseConfig.weights,
      currentUserId: currentUserId,
      streak: _streak,
    );

    _scoreNotifier.value = result;
  }

  /// Load initial data that isn't streamed (streak, member count, invite).
  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _firestoreService.getCheckInStreak(widget.spaceId),
        _firestoreService.getSpaceWithMembers(widget.spaceId),
      ]);

      final streak = results[0] as int;
      final space = results[1] as Map<String, dynamic>?;
      final memberIds =
          List<String>.from(space?['memberIds'] as List? ?? []);

      if (mounted) {
        final oldStreak = _streak;
        setState(() {
          _streak = streak;
          _memberCount = memberIds.length;
          _isLoading = false;
        });

        // Pulse the streak badge when a new day is achieved
        if (streak > oldStreak && oldStreak > 0) {
          _streakPulseController.forward(from: 0);
        }

        // Load invite code if solo
        if (_memberCount == 1) {
          _loadInviteCode();
        }

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

  Future<void> _loadInviteCode() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final code = await _firestoreService.getOrCreateInvite(
        spaceId: widget.spaceId,
        userId: userId,
      );
      if (mounted) setState(() => _inviteCode = code);
    } catch (e) {
      debugPrint('Error loading invite code: $e');
    }
  }

  Future<void> _loadInviteCardState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _inviteCardDismissed = prefs.getBool(_kInviteCardDismissedKey) ?? false;
    });
  }

  Future<void> _dismissInviteCard() async {
    HapticFeedback.lightImpact();
    setState(() => _inviteCardDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInviteCardDismissedKey, true);
  }

  void _shareInviteCode() {
    if (_inviteCode == null) return;
    Share.share(
      'Join my space on Kairos! Use code: $_inviteCode',
      subject: 'Kairos Invite',
    );
  }

  Future<void> _loadPromptMoment() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final moments = await _firestoreService.getPastMomentsAwaitingMemory(
        widget.spaceId,
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _promptMoment = moments.isNotEmpty ? moments.first : null);
    } catch (e) {
      debugPrint('Error loading prompt moment: $e');
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();

    try {
      final results = await Future.wait([
        _firestoreService.getCheckInStreak(widget.spaceId),
        _firestoreService.getSpaceWithMembers(widget.spaceId),
      ]);

      if (!mounted) return;

      final streak = results[0] as int;
      final space = results[1] as Map<String, dynamic>?;
      final memberIds =
          List<String>.from(space?['memberIds'] as List? ?? []);
      final oldStreak = _streak;

      setState(() {
        _streak = streak;
        _memberCount = memberIds.length;
      });

      if (streak > oldStreak && oldStreak > 0) {
        _streakPulseController.forward(from: 0);
      }

      _recomputeScores();
      _loadPromptMoment();

      // Re-animate health score on refresh
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _healthCardKey.currentState?.animateHealthScore(
            forceReanimate: true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error refreshing dashboard: $e');
    }

    if (mounted) HapticFeedback.lightImpact();
  }

  // ---------------------------------------------------------------------------
  // Actions — Memory Prompt
  // ---------------------------------------------------------------------------

  /// User lived the moment → create memory with lived sentiment.
  Future<void> _onLivedMoment() async {
    final moment = _promptMoment;
    if (moment == null) return;
    FocusScope.of(context).unfocus();

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.createPromptMemory(
        spaceId: widget.spaceId,
        moment: moment,
        userId: userId,
        userName: userName,
        sentiment: MemorySentiment.lived,
      );

      if (mounted) {
        setState(() {
          _livedMoment = moment;
          _promptMoment = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create memory: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// User missed the moment → create memory with missed sentiment.
  Future<void> _onMissedMoment() async {
    final moment = _promptMoment;
    if (moment == null) return;
    FocusScope.of(context).unfocus();

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.createPromptMemory(
        spaceId: widget.spaceId,
        moment: moment,
        userId: userId,
        userName: userName,
        sentiment: MemorySentiment.missed,
      );

      if (mounted) _loadPromptMoment();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update moment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Opens a moment or check-in details sheet by entity ID.
  /// Called from notification deep links.
  Future<void> openEntityById({
    required String entityType,
    required String entityId,
  }) async {
    if (entityType == 'moment' && entityId.isNotEmpty) {
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
    final result = _scoreNotifier.value;
    final hasBothCheckedIn =
        result.userCheckInCount > 0 && result.partnerCheckInCount > 0;

    if (!hasBothCheckedIn) {
      _showHealthPreview();
      return;
    }

    showHealthDetailsSheet(
      context: context,
      scoreResult: result,
      streak: _streak,
    );
  }

  void _showHealthPreview() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.darkCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentRed.withValues(alpha: 0.7),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Health Score',
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isSoloMode
                    ? 'This is your personal pulse trend. Once your partner joins and you both check in, this mosaic will come alive with colours that reflect your shared health.'
                    : 'Once all the members of the space start checking in, this mosaic will come alive with colours that represent your relationship health.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll see a detailed score breakdown, pulse attributes, weekly trends, and insights — all based on check-ins from both partners over the last 30 days.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        AppColors.accentRed.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.outfit(
                      color: AppColors.accentRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          if (moment.isSyncedToCalendar) {
            final userId = _authService.currentUser?.uid;
            if (userId != null) {
              final config =
                  await _firestoreService.getIntegrationConfig(userId);
              if (config.hasCalendar) {
                await CalendarService().deleteCalendarEvents(
                  moment: moment,
                  integration: config.calendar!,
                );
              }
            }
          }

          await _firestoreService.updateMomentStatus(
            spaceId: widget.spaceId,
            momentId: moment.id,
            status: MomentStatus.cancelled,
          );
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
      case EntityType.memory:
        _openMemoryFromActivity(activity);
        break;
      case EntityType.space:
      case null:
        break;
    }
  }

  Future<void> _openMomentFromActivity(Activity activity) async {
    final entityId = activity.entityId;
    if (entityId == null || entityId.isEmpty) return;

    final cached = _momentsNotifier.value
        .where((m) => m.id == entityId)
        .firstOrNull;
    if (cached != null) {
      _showMomentDetails(cached);
      return;
    }

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

  Future<void> _openMemoryFromActivity(Activity activity) async {
    final entityId = activity.entityId;
    if (entityId == null || entityId.isEmpty) return;

    try {
      final memory = await _firestoreService.getMemory(
        spaceId: widget.spaceId,
        memoryId: entityId,
      );
      if (!mounted || memory == null) return;

      // If moment-linked, open unified moment sheet
      if (memory.momentId != null) {
        final moment = await _firestoreService.getMoment(
          spaceId: widget.spaceId,
          momentId: memory.momentId!,
        );
        if (moment != null && mounted) {
          _showMomentDetails(moment);
          return;
        }
      }
      // Fallback: push to memory detail route
      if (mounted) context.push('/memory/${widget.spaceId}/$entityId');
    } catch (e) {
      debugPrint('Error opening memory from activity: $e');
    }
  }

  void _showCheckinDetails(Activity activity) {
    final currentUserId = _authService.currentUser?.uid;
    final displayName =
        (currentUserId != null && activity.actorId == currentUserId)
        ? 'You'
        : activity.actorName;

    // Parse scores from activity metadata — graceful on malformed data
    Map<String, int> scores = {};
    ConfigSnapshot configSnapshot = const ConfigSnapshot(
      activeAttributes: [],
      weights: {},
    );

    try {
      if (activity.metadata?['scores'] is Map) {
        final raw = Map<String, dynamic>.from(
            activity.metadata!['scores'] as Map);
        scores = raw.map(
            (k, v) => MapEntry(k, ((v as Map)['value'] as num).toInt()));
        configSnapshot = ConfigSnapshot.fromScoresMap(raw);
      }
    } catch (_) {
      // Old data format — won't render scores but won't crash
    }

    showCheckinDetailsSheet(
      context: context,
      actorName: displayName,
      timestamp: activity.timestamp,
      scores: scores,
      configSnapshot: configSnapshot,
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
            _buildStreakBadge(),
            const SizedBox(height: 12),
            _buildMainGrid(),
            const SizedBox(height: 12),
            if (_isSoloMode && !_inviteCardDismissed) ...[
              _buildInvitePartnerCard(),
              const SizedBox(height: 12),
            ],
            if (_promptMoment != null) ...[
              MemoryPromptCard(
                moment: _promptMoment!,
                onLived: _onLivedMoment,
                onMissed: _onMissedMoment,
              ),
              const SizedBox(height: 12),
            ],
            if (_livedMoment != null) ...[
              _buildLivedMomentCard(),
              const SizedBox(height: 16),
            ],
            _buildActivityTrail(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Streak Badge
  // ---------------------------------------------------------------------------

  Widget _buildStreakBadge() {
    final isActive = _streak > 0;

    return GestureDetector(
      onTap: _showHealthDetails,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _streakPulseController,
        builder: (context, child) {
          final pulseScale =
              1.0 + (_streakPulseController.value * 0.15 *
                  (1 - _streakPulseController.value));
          return Transform.scale(
            scale: _streakPulseController.isAnimating ? pulseScale : 1.0,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accentRed.withValues(alpha: 0.12)
                : AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: isActive
                    ? AppColors.accentRed
                    : AppColors.warmMuted,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$_streak',
                style: GoogleFonts.outfit(
                  color: isActive
                      ? AppColors.accentRed
                      : AppColors.warmMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _streak == 1 ? 'day' : 'days',
                style: GoogleFonts.inter(
                  color: isActive
                      ? AppColors.accentRed.withValues(alpha: 0.7)
                      : AppColors.warmMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Invite Partner Card (Solo Mode)
  // ---------------------------------------------------------------------------

  Widget _buildInvitePartnerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.accentRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invite your partner',
                  style: GoogleFonts.outfit(
                    color: AppColors.warmLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _dismissInviteCard,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.warmMuted,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Share this code so your partner can join your space and start checking in together.',
            style: GoogleFonts.inter(
              color: AppColors.warmDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_inviteCode != null) ...[
            Row(
              children: [
                // Code display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _inviteCode!,
                        style: GoogleFonts.outfit(
                          color: AppColors.warmLight,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Share button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _shareInviteCode();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.share_rounded,
                      color: AppColors.pureBlack,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.warmMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lived Moment Card
  // ---------------------------------------------------------------------------

  Widget _buildLivedMomentCard() {
    final moment = _livedMoment!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              getMomentTypeIconWidget(moment.type, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  moment.name,
                  style: GoogleFonts.outfit(
                    color: AppColors.warmLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              context.push(
                '/memory/${widget.spaceId}/create',
                extra: moment,
              );
              setState(() => _livedMoment = null);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Record Memory',
                  style: GoogleFonts.outfit(
                    color: AppColors.accentRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main Grid
  // ---------------------------------------------------------------------------

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
              builder: (context, allMoments, _) {
                final moments = allMoments
                    .where((m) =>
                        !m.isPast && m.id != _promptMoment?.id)
                    .toList();
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
          // Right column — Health/Trend card + Check-in
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildHealthOrTrendCard()),
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

  /// Renders HealthCard (shared mode) or PersonalTrendCard (solo mode).
  Widget _buildHealthOrTrendCard() {
    if (_isSoloMode) {
      return PersonalTrendCard(
        checkIns: _cachedCheckIns,
        streak: _streak,
        onTap: _showHealthPreview,
      );
    }

    return ValueListenableBuilder<ScoreResult>(
      valueListenable: _scoreNotifier,
      builder: (context, result, _) {
        return RepaintBoundary(
          child: HealthCard(
            key: _healthCardKey,
            scoreResult: result,
            onTap: _showHealthDetails,
          ),
        );
      },
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
