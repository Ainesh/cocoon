/// Dashboard screen for Couple Space app.
///
/// Main screen displaying relationship overview, upcoming events,
/// health metrics, and partner invite functionality.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/space_event.dart';
import '../models/user_checkin.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Main dashboard for a couple space.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Navigation state
  int _currentNavIndex = 0;

  // Loading state
  bool _isLoading = true;
  bool _isEventsLoading = true;
  String? _eventsError;

  // Space data
  String _spaceName = 'Our Space';
  int _memberCount = 0;
  String? _inviteCode;

  // Events data
  StreamSubscription<List<SpaceEvent>>? _eventsSubscription;
  List<SpaceEvent> _upcomingEvents = [];

  // Check-in data
  CheckInStats _checkInStats = CheckInStats.empty;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isCheckInLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpaceData();
    _subscribeToEvents();
    _loadCheckInData();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadSpaceData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      // Get space with members
      final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);

      if (space != null) {
        final members = List.from(space['members'] ?? []);
        setState(() {
          _spaceName = space['name'] ?? 'Our Space';
          _memberCount = members.length;
        });

        // Get or create invite code if only 1 member
        if (_memberCount == 1) {
          final inviteCode = await _firestoreService.getOrCreateInvite(
            spaceId: widget.spaceId,
            userId: userId,
          );
          setState(() => _inviteCode = inviteCode);
        }
      }
    } catch (e) {
      debugPrint('Error loading space: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToEvents() {
    _eventsSubscription?.cancel();
    setState(() {
      _isEventsLoading = true;
      _eventsError = null;
    });

    _eventsSubscription = _firestoreService
        .watchUpcomingEvents(widget.spaceId, daysAhead: 14)
        .listen(
      (events) {
        setState(() {
          _upcomingEvents = events;
          _isEventsLoading = false;
          _eventsError = null;
        });
      },
      onError: (error) {
        debugPrint('Error loading events: $error');
        setState(() {
          _isEventsLoading = false;
          _eventsError = 'Failed to load events';
        });
      },
    );
  }

  Future<void> _onRefresh() async {
    await _loadSpaceData();
    _subscribeToEvents();
    _loadCheckInData();
  }

  Future<void> _loadCheckInData() async {
    setState(() => _isCheckInLoading = true);

    try {
      final stats = await _firestoreService.getSpaceCheckInStats(
        widget.spaceId,
        checkInsPerUser: 4,
      );
      final activity = await _firestoreService.getRecentCheckInActivity(
        widget.spaceId,
        limit: 5,
      );

      setState(() {
        _checkInStats = stats;
        _recentActivity = activity;
        _isCheckInLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading check-in data: $e');
      setState(() => _isCheckInLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Event Helpers
  // ---------------------------------------------------------------------------

  /// Gets the next upcoming event (earliest in the list).
  SpaceEvent? get _nextEvent {
    if (_upcomingEvents.isEmpty) return null;
    return _upcomingEvents.first;
  }

  /// Gets events within the next 7 days, grouped by day.
  Map<String, List<SpaceEvent>> get _thisWeekEvents {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final dayFormat = DateFormat('EEE');

    final weekEvents = _upcomingEvents.where((e) {
      return e.scheduledAt.isBefore(weekEnd);
    }).toList();

    final grouped = <String, List<SpaceEvent>>{};
    for (final event in weekEvents) {
      final dayKey = dayFormat.format(event.scheduledAt);
      grouped.putIfAbsent(dayKey, () => []).add(event);
    }
    return grouped;
  }

  String _formatEventTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return 'Today ${DateFormat.jm().format(dateTime)}';
    }

    final dayFormat = DateFormat('EEE MMM d');
    final timeFormat = DateFormat.jm();
    return '${dayFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
  }

  // ---------------------------------------------------------------------------
  // Invite Actions
  // ---------------------------------------------------------------------------

  String _getInviteUrl() {
    if (_inviteCode == null) return '';

    if (kIsWeb) {
      final baseUrl = Uri.base.origin;
      return '$baseUrl/#/login?code=$_inviteCode';
    } else {
      return 'https://couplespace.app/#/login?code=$_inviteCode';
    }
  }

  void _copyInviteLink() {
    final inviteUrl = _getInviteUrl();
    if (inviteUrl.isEmpty) return;

    Clipboard.setData(ClipboardData(text: inviteUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite link copied!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInviteLink() {
    final inviteUrl = _getInviteUrl();
    if (inviteUrl.isEmpty) return;

    Share.share(
      'Join my couple space "$_spaceName"!\n\n$inviteUrl',
      subject: 'Join $_spaceName',
    );
  }

  // ---------------------------------------------------------------------------
  // Event Creation
  // ---------------------------------------------------------------------------

  void _showCreateEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EventCreationSheet(
        spaceId: widget.spaceId,
        firestoreService: _firestoreService,
        authService: _authService,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_spaceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: _currentNavIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateEventSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add event'),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_currentNavIndex) {
      0 => _buildHomeTab(theme),
      1 => _buildPlaceholderTab(theme, 'Calendar', Icons.calendar_month_outlined),
      2 => _buildPlaceholderTab(theme, 'Check-ins', Icons.check_circle_outline),
      3 => _buildPlaceholderTab(theme, 'Agreements', Icons.handshake_outlined),
      4 => _buildPlaceholderTab(theme, 'Settings', Icons.settings_outlined),
      _ => _buildHomeTab(theme),
    };
  }

  // ---------------------------------------------------------------------------
  // Home Tab
  // ---------------------------------------------------------------------------

  Widget _buildHomeTab(ThemeData theme) {
    if (_isLoading) return _buildLoadingSkeleton(theme);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_memberCount == 1 && _inviteCode != null) ...[
              _buildInvitePartnerCard(theme),
              const SizedBox(height: 16),
            ],
            _buildEventsSection(theme),
            const SizedBox(height: 16),
            _buildHealthCard(theme),
            const SizedBox(height: 16),
            _buildRecentActivityCard(theme),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(ThemeData theme) {
    if (_recentActivity.isEmpty && !_isCheckInLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isCheckInLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ..._recentActivity.map((activity) => _buildActivityItem(theme, activity)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(ThemeData theme, Map<String, dynamic> activity) {
    final checkIn = activity['checkIn'] as UserCheckIn;
    final userName = activity['userName'] as String;
    final currentUserId = _authService.currentUser?.uid;
    final isCurrentUser = checkIn.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'You checked in' : '$userName checked in',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  checkIn.timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildMiniScore(theme, '💙', checkIn.connection),
              const SizedBox(width: 6),
              _buildMiniScore(theme, '❤️', checkIn.intimacy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScore(ThemeData theme, String emoji, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            score.toString(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Events Section
  // ---------------------------------------------------------------------------

  Widget _buildEventsSection(ThemeData theme) {
    if (_isEventsLoading) {
      return _buildSkeletonCard(theme, 150);
    }

    if (_eventsError != null) {
      return _buildEventsErrorCard(theme);
    }

    if (_upcomingEvents.isEmpty) {
      return _buildNoEventsCard(theme);
    }

    return Column(
      children: [
        _buildNextUpCard(theme),
        const SizedBox(height: 16),
        _buildThisWeekCard(theme),
      ],
    );
  }

  Widget _buildEventsErrorCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _eventsError!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _subscribeToEvents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No plans yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a date night or a weekly check-in to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showCreateEventSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first event'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

  Widget _buildInvitePartnerCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add_rounded, color: theme.colorScheme.onPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite your partner',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Share the link below to connect',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Invite Code',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _inviteCode ?? '------',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyInviteLink,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _shareInviteLink,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextUpCard(ThemeData theme) {
    final nextEvent = _nextEvent;
    if (nextEvent == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                nextEvent.type.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next up',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextEvent.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatEventTime(nextEvent.scheduledAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(ThemeData theme) {
    final hasData = _checkInStats.checkInCount > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Relationship Health',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isCheckInLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!hasData)
              _buildNoCheckInsPrompt(theme)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildHealthMetric(
                      theme,
                      'Connection',
                      '💙',
                      _checkInStats.avgConnection,
                      _checkInStats.connectionTrend,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHealthMetric(
                      theme,
                      'Intimacy',
                      '❤️',
                      _checkInStats.avgIntimacy,
                      _checkInStats.intimacyTrend,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Based on ${_checkInStats.checkInCount} recent check-ins',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/checkin/${widget.spaceId}'),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Check-in now'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCheckInsPrompt(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.sentiment_neutral_rounded,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No check-ins yet',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check in regularly to track your relationship health',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHealthMetric(
    ThemeData theme,
    String label,
    String emoji,
    double value,
    double trend,
  ) {
    final trendIcon = trend > 0.05
        ? Icons.trending_up
        : trend < -0.05
            ? Icons.trending_down
            : Icons.trending_flat;
    final trendColor = trend > 0.05
        ? Colors.green
        : trend < -0.05
            ? Colors.red
            : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value.toStringAsFixed(1),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Icon(trendIcon, color: trendColor, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekCard(ThemeData theme) {
    final weekEvents = _thisWeekEvents;
    if (weekEvents.isEmpty) return const SizedBox.shrink();

    // Flatten events for display
    final allWeekEvents = <SpaceEvent>[];
    weekEvents.forEach((_, events) => allWeekEvents.addAll(events));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'This Week',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...allWeekEvents.map((event) => _buildEventItem(theme, event)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(ThemeData theme, SpaceEvent event) {
    final dayFormat = DateFormat('EEE');
    final dayLabel = dayFormat.format(event.scheduledAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(event.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              event.title,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            dayLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading & Placeholder
  // ---------------------------------------------------------------------------

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSkeletonCard(theme, 100),
          const SizedBox(height: 16),
          _buildSkeletonCard(theme, 200),
          const SizedBox(height: 16),
          _buildSkeletonCard(theme, 180),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(ThemeData theme, double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(ThemeData theme, String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Navigation
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav(ThemeData theme) {
    return NavigationBar(
      selectedIndex: _currentNavIndex,
      onDestinationSelected: (index) => setState(() => _currentNavIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.check_circle_outline),
          selectedIcon: Icon(Icons.check_circle_rounded),
          label: 'Check-ins',
        ),
        NavigationDestination(
          icon: Icon(Icons.handshake_outlined),
          selectedIcon: Icon(Icons.handshake_rounded),
          label: 'Agreements',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }
}

// =============================================================================
// Event Creation Bottom Sheet
// =============================================================================

class _EventCreationSheet extends StatefulWidget {
  const _EventCreationSheet({
    required this.spaceId,
    required this.firestoreService,
    required this.authService,
  });

  final String spaceId;
  final FirestoreService firestoreService;
  final AuthService authService;

  @override
  State<_EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends State<_EventCreationSheet> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EventType _selectedType = EventType.dateNight;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = _selectedType.label;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onTypeChanged(EventType type) {
    setState(() {
      _selectedType = type;
      // Update title to default for type if it matches the previous default
      if (_titleController.text == EventType.dateNight.label ||
          _titleController.text == EventType.checkIn.label ||
          _titleController.text == EventType.special.label) {
        _titleController.text = type.label;
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = widget.authService.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final scheduledAt = DateTime(
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
        scheduledAt: scheduledAt,
        createdBy: userId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Event created!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create event: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Add Event',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Event Type Selector
              Text(
                'Event Type',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<EventType>(
                segments: EventType.values.map((type) {
                  return ButtonSegment<EventType>(
                    value: type,
                    label: Text(type.label),
                    icon: Text(type.emoji),
                  );
                }).toList(),
                selected: {_selectedType},
                onSelectionChanged: (selection) {
                  _onTypeChanged(selection.first);
                },
              ),
              const SizedBox(height: 20),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter event title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeTile(
                      theme,
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('EEE, MMM d').format(_selectedDate),
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateTimeTile(
                      theme,
                      icon: Icons.access_time_rounded,
                      label: _selectedTime.format(context),
                      onTap: _selectTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
