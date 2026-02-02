/// Dashboard tab for Cocoon app.
///
/// Modern dark UI with lime green accent, featuring circular
/// dotted progress indicators for health metrics and check-in feedback.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/space_event.dart';
import '../models/user_checkin.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// Theme constants - Dark with warm red accent
const _pureBlack = Color(0xFF0A0A0A);
const _darkCard = Color(0xFF161616);
const _darkCardLight = Color(0xFF1E1E1E);
const _accentRed = Color(0xFFE84545);
const _warmLight = Color(0xFFEDE6DB); // Warm cream instead of white
const _warmDim = Color(0xFF9A938A); // Warm gray
const _warmMuted = Color(0xFF6B665F); // Muted warm

/// Dashboard tab widget.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.spaceId});

  final String spaceId;

  void showCreateEventSheet(BuildContext context, String spaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _darkCard,
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

class _DashboardTabState extends State<DashboardTab> with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();

  bool _isLoading = true;

  StreamSubscription<List<SpaceEvent>>? _eventsSubscription;
  List<SpaceEvent> _upcomingEvents = [];

  CheckInStats _checkInStats = CheckInStats.empty;
  List<Map<String, dynamic>>? _dailyScores;
  int _streak = 0;

  // Health score animation
  late AnimationController _healthAnimController;
  late Animation<double> _healthAnimation;
  double _targetProgress = 0;
  int _lastHapticDot = -1;
  static const int _totalDots = 32;

  // Card flip animation
  AnimationController? _flipController;
  String _healthRemark = '';

  @override
  void initState() {
    super.initState();
    _healthAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _healthAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _healthAnimController, curve: _suspenseCurve),
    );
    _healthAnimController.addListener(_onHealthAnimationUpdate);
    _healthAnimController.addStatusListener(_onHealthAnimationStatus);

    _flipController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _loadData();
  }

  // Custom curve: fast start, dramatic slowdown at 80%, crawl to finish
  static const _suspenseCurve = _SuspensefulCurve();

  void _onHealthAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Animation done - flip to show remark
      _flipToRemark();
    }
  }

  Future<void> _flipToRemark() async {
    if (!mounted || _flipController == null) return;
    
    await _flipController!.forward();
    HapticFeedback.mediumImpact(); // Haptic when landing on back
    
    // Stay on back for 2 seconds
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;
    
    // Flip back
    await _flipController!.reverse();
    HapticFeedback.mediumImpact(); // Haptic when landing on front
  }

  void _onHealthAnimationUpdate() {
    // Calculate which dot we're on based on animation value
    final currentDot = (_healthAnimation.value * _totalDots).floor();
    
    // Trigger haptic for each new dot
    if (currentDot > _lastHapticDot && currentDot <= (_targetProgress * _totalDots).ceil()) {
      _lastHapticDot = currentDot;
      HapticFeedback.lightImpact();
    }
    setState(() {});
  }

  void _animateHealthScore(double progress) {
    _targetProgress = progress;
    _lastHapticDot = -1;
    _healthAnimation = Tween<double>(
      begin: 0,
      end: progress,
    ).animate(
      CurvedAnimation(parent: _healthAnimController, curve: _suspenseCurve),
    );
    _healthAnimController.forward(from: 0);
  }

  void _animateHealthScoreFromStats() {
    final connectionPct = _checkInStats.avgConnection * 10;
    final intimacyPct = _checkInStats.avgIntimacy * 10;
    final peacePct = (10 - _checkInStats.avgStress) * 10;
    final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3).round();
    final progress = overallHealth / 100;
    
    // Store the remark for flip animation
    _healthRemark = _getHealthRemark(overallHealth);
    
    // Small delay before starting animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animateHealthScore(progress);
    });
  }

  @override
  void dispose() {
    _healthAnimController.removeListener(_onHealthAnimationUpdate);
    _healthAnimController.removeStatusListener(_onHealthAnimationStatus);
    _healthAnimController.dispose();
    _flipController?.dispose();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _firestoreService.getSpaceCheckInStats(widget.spaceId),
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
        _animateHealthScoreFromStats();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accentRed));
    }

    return RefreshIndicator(
      color: _accentRed,
      backgroundColor: _darkCard,
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
          // Left column - Upcoming events
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildUpcomingEventCard(0)),
                const SizedBox(height: 12),
                Expanded(child: _buildUpcomingEventCard(1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right column - Health card + Check-in below
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildHealthCard()),
                const SizedBox(height: 12),
                _buildCheckInCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventCard(int index) {
    // For index 0, show "Today" card; for index 1, show "Next" upcoming event
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (index == 0) {
      // Today's events
      final todayEvents = _upcomingEvents.where((e) {
        final eventDay = DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day);
        return eventDay.isAtSameMomentAs(today);
      }).toList();
      
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _warmMuted.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: _accentRed.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today',
                style: GoogleFonts.outfit(
                  color: _warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (todayEvents.isNotEmpty) ...[
                Text(
                  todayEvents.first.title,
                  style: GoogleFonts.inter(
                    color: _warmLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(todayEvents.first.scheduledAt),
                  style: GoogleFonts.inter(
                    color: _warmDim,
                    fontSize: 13,
                  ),
                ),
              ] else
                Text(
                  'Nothing planned',
                  style: GoogleFonts.inter(
                    color: _warmDim,
                    fontSize: 15,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    // Next upcoming event (not today)
    final futureEvents = _upcomingEvents.where((e) {
      final eventDay = DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day);
      return eventDay.isAfter(today);
    }).toList();
    
    final event = futureEvents.isNotEmpty ? futureEvents.first : null;
    
    if (event != null) {
      final eventDay = DateTime(event.scheduledAt.year, event.scheduledAt.month, event.scheduledAt.day);
      final daysUntil = eventDay.difference(today).inDays;
      
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _warmMuted.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: _accentRed.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                daysUntil == 1 ? 'Tomorrow' : DateFormat('EEE, MMM d').format(event.scheduledAt),
                style: GoogleFonts.inter(
                  color: _warmMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                event.title,
                style: GoogleFonts.inter(
                  color: _warmLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(event.scheduledAt),
                style: GoogleFonts.inter(
                  color: _warmDim,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Empty state - add event (clickable - stronger glow)
    return GestureDetector(
      onTap: () => widget.showCreateEventSheet(context, widget.spaceId),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accentRed.withValues(alpha: 0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: _accentRed.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next',
                style: GoogleFonts.outfit(
                  color: _warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                'Plan something',
                style: GoogleFonts.inter(
                  color: _warmDim,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHealthRemark(int score) {
    if (score >= 85) return 'Deeply Connected';
    if (score >= 70) return 'Thriving Together';
    if (score >= 50) return 'Growing Stronger';
    if (score >= 30) return 'Room to Grow';
    return 'Needs Attention';
  }

  Widget _buildHealthCard() {
    // Use animated progress for the visual and number
    final animatedProgress = _healthAnimation.value;
    
    // If flip controller not ready, just show front
    if (_flipController == null) {
      return _buildHealthCardFront(animatedProgress);
    }
    
    return AnimatedBuilder(
      animation: _flipController!,
      builder: (context, child) {
        final angle = _flipController!.value * math.pi;
        final isBack = angle > math.pi / 2;
        
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: isBack ? _buildHealthCardBack() : _buildHealthCardFront(animatedProgress),
        );
      },
    );
  }

  Widget _buildHealthCardBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi), // Mirror the back
      child: GestureDetector(
        onTap: () => _showHealthDetails(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _darkCardLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _accentRed.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _healthRemark,
                style: GoogleFonts.cormorantGaramond(
                  color: _accentRed,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCardFront(double animatedProgress) {
    return GestureDetector(
      onTap: () => _showHealthDetails(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accentRed,
              _accentRed.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _accentRed.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relationship Health',
              style: GoogleFonts.outfit(
                color: _pureBlack.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            // Score with circular progress
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: _DottedCircleProgressPainter(
                        progress: animatedProgress,
                        activeColor: _pureBlack,
                        inactiveColor: _pureBlack.withValues(alpha: 0.2),
                        dotCount: _totalDots,
                        dotRadius: 3.2,
                      ),
                    ),
                    Text(
                      (animatedProgress * 100).round().toString(),
                      style: GoogleFonts.outfit(
                        color: _pureBlack,
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Individual metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSmallIndicator(Icons.favorite_rounded, _checkInStats.avgConnection / 10),
                _buildSmallIndicatorSvg('assets/icons/flame.svg', _checkInStats.avgIntimacy / 10),
                _buildSmallIndicatorSvg('assets/icons/peace.svg', (10 - _checkInStats.avgStress) / 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCheckInCard() {
    return GestureDetector(
      onTap: () => context.push('/checkin/${widget.spaceId}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _darkCardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accentRed.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Check in',
              style: GoogleFonts.outfit(
                color: _accentRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.play_circle_filled_rounded,
              color: _accentRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showHealthDetails(BuildContext context) {
    // Scores are 1-10, convert to 0-100 scale
    final connectionPct = _checkInStats.avgConnection * 10;
    final intimacyPct = _checkInStats.avgIntimacy * 10;
    final peacePct = (10 - _checkInStats.avgStress) * 10;
    
    final overallHealth = ((connectionPct + intimacyPct + peacePct) / 3).round();
    final remark = _getHealthRemark(overallHealth);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          Text(
                            overallHealth.toString(),
                            style: GoogleFonts.outfit(
                              color: _accentRed,
                              fontSize: 80,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            remark,
                            style: GoogleFonts.cormorantGaramond(
                              color: _warmLight,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Relationship Health Score',
                            style: GoogleFonts.inter(
                              color: _warmDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Individual metrics
                    Text(
                      'BREAKDOWN',
                      style: GoogleFonts.inter(
                        color: _warmMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedMetric(
                      'Connection',
                      Icons.favorite_rounded,
                      connectionPct,
                      _checkInStats.connectionTrend,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailedMetric(
                      'Intimacy',
                      Icons.local_fire_department_rounded,
                      intimacyPct,
                      _checkInStats.intimacyTrend,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailedMetric(
                      'Peace',
                      Icons.self_improvement_rounded,
                      peacePct,
                      -_checkInStats.stressTrend, // Inverted since lower stress is better
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Trend visualization
                    Text(
                      'RECENT TREND',
                      style: GoogleFonts.inter(
                        color: _warmMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTrendChart(),
                    
                    const SizedBox(height: 32),
                    
                    // Stats
                    Text(
                      'INSIGHTS',
                      style: GoogleFonts.inter(
                        color: _warmMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInsightCard(
                            'Check-ins',
                            _checkInStats.checkInCount.toString(),
                            'Total recorded',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInsightCard(
                            'Streak',
                            _streak > 0 ? '$_streak day${_streak > 1 ? 's' : ''} 🔥' : 'Start!',
                            _streak > 0 ? 'Keep it going!' : 'Check in today',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedMetric(String label, IconData icon, double value, double trend) {
    final trendPositive = trend > 0;
    final trendIcon = trendPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final trendColor = trendPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _accentRed, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _warmDim,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value.round().toString(),
                      style: GoogleFonts.spaceMono(
                        color: _warmLight,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '/100',
                      style: GoogleFonts.inter(
                        color: _warmMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trend != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(trendIcon, color: trendColor, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${trend.abs().toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      color: trendColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTrendChart() {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final scores = _dailyScores ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              // Use real data if available
              final dayData = index < scores.length ? scores[index] : null;
              final score = dayData?['score'] as double? ?? 0;
              final hasCheckIn = dayData?['hasCheckIn'] as bool? ?? false;
              final date = dayData?['date'] as DateTime?;
              
              // Scale score (0-100) to bar height (10-80)
              final height = hasCheckIn ? (10 + (score * 0.7)).clamp(10.0, 80.0) : 10.0;
              final isToday = index == 6;
              
              // Get day label from actual date
              final dayLabel = date != null 
                  ? dayLabels[date.weekday - 1] 
                  : dayLabels[index];
              
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: height,
                    decoration: BoxDecoration(
                      color: hasCheckIn 
                          ? (isToday ? _accentRed : _accentRed.withValues(alpha: 0.6))
                          : _warmMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayLabel,
                    style: GoogleFonts.inter(
                      color: isToday ? _warmLight : _warmMuted,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (scores.isEmpty || !scores.any((d) => d['hasCheckIn'] == true))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No check-ins this week',
                style: GoogleFonts.inter(
                  color: _warmMuted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _warmMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: _accentRed,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _warmDim,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIndicator(IconData icon, double progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(44, 44),
                painter: _ContinuousCircleProgressPainter(
                  progress: progress,
                  activeColor: _pureBlack,
                  inactiveColor: _pureBlack.withValues(alpha: 0.2),
                  strokeWidth: 3,
                ),
              ),
              Icon(icon, color: _pureBlack, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallIndicatorSvg(String svgPath, double progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(44, 44),
                painter: _ContinuousCircleProgressPainter(
                  progress: progress,
                  activeColor: _pureBlack,
                  inactiveColor: _pureBlack.withValues(alpha: 0.2),
                  strokeWidth: 3,
                ),
              ),
              SvgPicture.asset(
                svgPath,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(_pureBlack, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ],
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
              color: _warmMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        ..._upcomingEvents.take(3).map((event) => _buildEventItem(event)),
      ],
    );
  }

  Widget _buildEventItem(SpaceEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(event.scheduledAt.year, event.scheduledAt.month, event.scheduledAt.day);
    final daysUntil = eventDay.difference(today).inDays;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              event.type == EventType.dateNight ? Icons.dinner_dining_rounded : Icons.event_rounded,
              color: _accentRed,
              size: 20,
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
                    color: _warmLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE, MMM d • HH:mm').format(event.scheduledAt),
                  style: GoogleFonts.inter(
                    color: _warmMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: daysUntil <= 1 
                  ? _accentRed.withValues(alpha: 0.15) 
                  : _darkCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              daysUntil == 0
                  ? 'Today'
                  : daysUntil == 1
                      ? 'Tomorrow'
                      : '${daysUntil}d',
              style: GoogleFonts.inter(
                color: daysUntil <= 1 ? _accentRed : _warmDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Dotted Circle Progress Painter
// ---------------------------------------------------------------------------

class _DottedCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int dotCount;
  final double dotRadius;

  _DottedCircleProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.dotCount,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - dotRadius - 4;

    final activeDots = (dotCount * progress).round();

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi / dotCount) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final paint = Paint()
        ..color = i < activeDots ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCircleProgressPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _ContinuousCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double strokeWidth;

  _ContinuousCircleProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth - 2;

    // Draw inactive background circle
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw active progress arc
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ContinuousCircleProgressPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

// ---------------------------------------------------------------------------
// Event Creation Sheet (kept for compatibility)
// ---------------------------------------------------------------------------

class EventCreationSheet extends StatefulWidget {
  const EventCreationSheet({
    super.key,
    required this.spaceId,
    required this.firestoreService,
    required this.authService,
  });

  final String spaceId;
  final FirestoreService firestoreService;
  final AuthService authService;

  @override
  State<EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends State<EventCreationSheet> {
  final _titleController = TextEditingController();
  EventType _selectedType = EventType.dateNight;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = widget.authService.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await widget.firestoreService.createEvent(
        spaceId: widget.spaceId,
        title: _titleController.text.trim(),
        type: _selectedType,
        scheduledAt: startTime,
        createdBy: userId,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'New Event',
            style: TextStyle(
              color: _warmLight,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: _warmLight),
            decoration: InputDecoration(
              labelText: 'Event title',
              labelStyle: const TextStyle(color: _warmMuted),
              filled: true,
              fillColor: _darkCardLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<EventType>(
            segments: const [
              ButtonSegment(value: EventType.dateNight, label: Text('Date Night')),
              ButtonSegment(value: EventType.checkIn, label: Text('Check-in')),
              ButtonSegment(value: EventType.special, label: Text('Special')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (v) => setState(() => _selectedType = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return _accentRed.withValues(alpha: 0.2);
                }
                return _darkCardLight;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accentRed;
                return _warmDim;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('MMM d').format(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentRed,
                    side: BorderSide(color: _accentRed.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (time != null) setState(() => _selectedTime = time);
                  },
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_selectedTime.format(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentRed,
                    side: BorderSide(color: _accentRed.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isCreating ? null : _createEvent,
            style: FilledButton.styleFrom(
              backgroundColor: _accentRed,
              foregroundColor: _pureBlack,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _pureBlack),
                  )
                : const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Custom curve following normal distribution pattern.
/// Fast at start, progressively slower towards the end (right half of bell curve).
class _SuspensefulCurve extends Curve {
  const _SuspensefulCurve();

  @override
  double transformInternal(double t) {
    // Normal distribution CDF approximation - maps time to progress
    // This creates the effect where early dots appear rapidly,
    // and the rate slows down following a bell curve pattern
    // Peak slowdown is at the very end
    
    // Use error function approximation for normal CDF
    // We want: fast start -> gradual slowdown -> crawl at end
    // This is like integrating right half of normal distribution
    
    // Simpler approach: use inverse of remaining distance
    // Progress = 1 - (1-t)^k where k controls the curve steepness
    const k = 3.5; // Higher = more dramatic slowdown at end
    return 1.0 - math.pow(1.0 - t, k).toDouble();
  }
}
