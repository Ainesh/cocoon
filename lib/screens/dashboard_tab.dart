/// Dashboard tab for Couple Space app.
///
/// Main home screen displaying relationship overview, upcoming events,
/// health metrics, and partner invite functionality with premium neumorphic UI.
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
import '../widgets/neumorphic_container.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _bodyGray = Color(0xFFD1D5DB);
const _dimText = Color(0xFF9CA3AF);
const _cardVariant = Color(0xFF2A2A2A);

/// Dashboard tab widget.
class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  /// Shows the create event sheet - called from MainShell.
  void showCreateEventSheet(BuildContext context, String spaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E1E),
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
  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

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

      final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);

      if (space != null) {
        final members = List.from(space['members'] ?? []);
        setState(() {
          _spaceName = space['name'] ?? 'Our Space';
          _memberCount = members.length;
        });

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

  Future<void> _onRefresh() async {
    await _loadSpaceData();
    _subscribeToEvents();
    _loadCheckInData();
  }

  // ---------------------------------------------------------------------------
  // Event Helpers
  // ---------------------------------------------------------------------------

  SpaceEvent? get _nextEvent {
    if (_upcomingEvents.isEmpty) return null;
    return _upcomingEvents.first;
  }

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
      const SnackBar(
        content: Text('Invite link copied!'),
        backgroundColor: _refinedRed,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
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
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingSkeleton();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _refinedRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_memberCount == 1 && _inviteCode != null) ...[
              _buildInvitePartnerCard(),
              const SizedBox(height: 8),
            ],
            _buildEventsSection(),
            const SizedBox(height: 8),
            _buildHealthCard(),
            const SizedBox(height: 8),
            _buildRecentActivityCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    if (_isEventsLoading) {
      return _buildSkeletonCard(150);
    }

    if (_eventsError != null) {
      return _buildEventsErrorCard();
    }

    if (_upcomingEvents.isEmpty) {
      return _buildNoEventsCard();
    }

    return Column(
      children: [
        _buildNextUpCard(),
        const SizedBox(height: 8),
        _buildThisWeekCard(),
      ],
    );
  }

  Widget _buildEventsErrorCard() {
    return PremiumCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: _refinedRed),
          const SizedBox(height: 16),
          Text(_eventsError!, style: const TextStyle(fontSize: 16, color: _bodyGray)),
          const SizedBox(height: 16),
          cardOutlinedButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: _subscribeToEvents,
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsCard() {
    return PremiumCard(
      padding: const EdgeInsets.all(32),
      child: EmptyState(
        icon: Icons.event_note_outlined,
        title: 'No plans yet',
        subtitle: 'Add a date night or a weekly check-in to get started.',
      ),
    );
  }

  Widget _buildInvitePartnerCard() {
    return PremiumCard(
      glowIntensity: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _refinedRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite your partner', style: cardHeadline(context)),
                    const SizedBox(height: 2),
                    const Text('Share the link below to connect', style: TextStyle(fontSize: 14, color: _dimText)),
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
              color: _cardVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _refinedRed.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('Invite Code', style: TextStyle(fontSize: 12, color: _dimText)),
                const SizedBox(height: 6),
                Text(
                  _inviteCode ?? '------',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _refinedRed,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: cardOutlinedButton(label: 'Copy Link', icon: Icons.link_rounded, onPressed: _copyInviteLink)),
              const SizedBox(width: 12),
              Expanded(child: cardButton(label: 'Share', icon: Icons.share_rounded, onPressed: _shareInviteLink)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextUpCard() {
    final nextEvent = _nextEvent;
    if (nextEvent == null) return const SizedBox.shrink();

    return PremiumCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _refinedRed.withValues(alpha: 0.2)),
            ),
            child: Text(nextEvent.type.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next up', style: TextStyle(fontSize: 14, color: _dimText)),
                const SizedBox(height: 4),
                Text(nextEvent.title, style: cardHeadline(context)),
                Text(_formatEventTime(nextEvent.scheduledAt), style: const TextStyle(fontSize: 14, color: _bodyGray)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _refinedRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    final hasData = _checkInStats.checkInCount > 0;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.favorite_rounded,
            title: 'Relationship Health',
          ),
          const SizedBox(height: 20),
          if (_isCheckInLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: _refinedRed)))
          else if (!hasData)
            _buildNoCheckInsPrompt()
          else ...[
            Row(
              children: [
                Expanded(child: MetricDisplay(emoji: '💙', label: 'Connection', value: _checkInStats.avgConnection.toStringAsFixed(1), trend: _checkInStats.connectionTrend)),
                const SizedBox(width: 16),
                Expanded(child: MetricDisplay(emoji: '❤️', label: 'Intimacy', value: _checkInStats.avgIntimacy.toStringAsFixed(1), trend: _checkInStats.intimacyTrend)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Based on ${_checkInStats.checkInCount} recent check-ins', style: const TextStyle(fontSize: 14, color: _dimText)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: cardButton(
              label: 'Check-in now',
              icon: Icons.edit_note_rounded,
              onPressed: () => context.push('/checkin/${widget.spaceId}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCheckInsPrompt() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardVariant,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sentiment_neutral_rounded, size: 48, color: _dimText),
        ),
        const SizedBox(height: 12),
        Text('No check-ins yet', style: cardTitle(context)),
        const SizedBox(height: 4),
        const Text(
          'Check in regularly to track your relationship health',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _dimText),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildThisWeekCard() {
    final weekEvents = _thisWeekEvents;
    if (weekEvents.isEmpty) return const SizedBox.shrink();

    final allWeekEvents = <SpaceEvent>[];
    weekEvents.forEach((_, events) => allWeekEvents.addAll(events));

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.date_range_rounded,
            title: 'This Week',
          ),
          const SizedBox(height: 16),
          ...allWeekEvents.map((event) => EventItem(
                emoji: event.type.emoji,
                title: event.title,
                subtitle: DateFormat('EEE').format(event.scheduledAt),
              )),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    if (_recentActivity.isEmpty && !_isCheckInLoading) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.history_rounded,
            title: 'Recent Activity',
          ),
          const SizedBox(height: 16),
          if (_isCheckInLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: _refinedRed)))
          else
            ..._recentActivity.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final checkIn = activity['checkIn'] as UserCheckIn;
    final userName = activity['userName'] as String;
    final currentUserId = _authService.currentUser?.uid;
    final isCurrentUser = checkIn.userId == currentUserId;

    return ActivityItem(
      title: isCurrentUser ? 'You checked in' : '$userName checked in',
      subtitle: checkIn.timeAgo,
      isCurrentUser: isCurrentUser,
      scores: [
        ScoreBadge(emoji: '💙', score: checkIn.connection),
        const SizedBox(width: 6),
        ScoreBadge(emoji: '❤️', score: checkIn.intimacy),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSkeletonCard(100),
          const SizedBox(height: 16),
          _buildSkeletonCard(200),
          const SizedBox(height: 16),
          _buildSkeletonCard(180),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _cardVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _refinedRed.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// =============================================================================
// Event Creation Bottom Sheet
// =============================================================================

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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
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
          const SnackBar(
            content: Text('Event created!'),
            backgroundColor: _refinedRed,
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
            backgroundColor: Colors.red.shade700,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Add Event', style: cardHeadline(context)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _lightText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Event Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _bodyGray)),
              const SizedBox(height: 8),
              SegmentedButton<EventType>(
                segments: EventType.values.map((type) {
                  return ButtonSegment<EventType>(value: type, label: Text(type.label), icon: Text(type.emoji));
                }).toList(),
                selected: {_selectedType},
                onSelectionChanged: (selection) => _onTypeChanged(selection.first),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return _refinedRed;
                    return _bodyGray;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: _lightText),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter event title',
                  labelStyle: const TextStyle(color: _bodyGray),
                  hintStyle: const TextStyle(color: _dimText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDateTimeTile(icon: Icons.calendar_today_rounded, label: DateFormat('EEE, MMM d').format(_selectedDate), onTap: _selectDate)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDateTimeTile(icon: Icons.access_time_rounded, label: _selectedTime.format(context), onTap: _selectTime)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: FilledButton.styleFrom(
                    backgroundColor: _refinedRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _cardVariant,
          border: Border.all(color: _refinedRed.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _refinedRed),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: _lightText))),
          ],
        ),
      ),
    );
  }
}
