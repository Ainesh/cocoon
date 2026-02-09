/// Check-ins tab for Couple Space app.
///
/// Displays a timeline of recent check-ins with premium neumorphic cards.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
const _greenAccent = Color(0xFF4ADE80);

/// Check-ins tab with timeline view.
class CheckInsTab extends StatefulWidget {
  const CheckInsTab({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<CheckInsTab> createState() => _CheckInsTabState();
}

class _CheckInsTabState extends State<CheckInsTab> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  List<UserCheckIn> _checkIns = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;

  String? get _currentUserId => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _subscribeToCheckIns();
    _loadUserNames();
  }

  @override
  void dispose() {
    _checkInsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToCheckIns() {
    _checkInsSubscription?.cancel();
    setState(() => _isLoading = true);

    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen(
      (checkIns) {
        setState(() {
          _checkIns = checkIns;
          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error loading check-ins: $error');
        setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _loadUserNames() async {
    try {
      final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);
      if (space != null) {
        final members = space['members'] as List? ?? [];
        final names = <String, String>{};
        for (final member in members) {
          final userId = member['userId'] as String?;
          final name = member['name'] as String?;
          if (userId != null && name != null) {
            names[userId] = name;
          }
        }
        setState(() => _userNames = names);
      }
    } catch (e) {
      debugPrint('Error loading user names: $e');
    }
  }

  String _getUserName(String userId) {
    if (userId == _currentUserId) return 'You';
    return _userNames[userId] ?? 'Partner';
  }

  String _getTrendArrow(int score) {
    if (score >= 8) return '↗️';
    if (score >= 6) return '→';
    if (score >= 4) return '↘️';
    return '↓';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _refinedRed, strokeWidth: 2),
      );
    }

    if (_checkIns.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _subscribeToCheckIns();
        await _loadUserNames();
      },
      color: _refinedRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _checkIns.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }
          return _buildCheckInCard(_checkIns[index - 1]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EmptyState(
          icon: Icons.favorite_outline_rounded,
          title: 'No check-ins yet',
          subtitle: 'Check in regularly to track how your relationship is doing.',
          actionLabel: 'First check-in',
          onAction: () => context.push('/checkin/${widget.spaceId}'),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Calculate stats
    final myCheckIns = _checkIns.where((c) => c.userId == _currentUserId).toList();
    final partnerCheckIns = _checkIns.where((c) => c.userId != _currentUserId).toList();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.insights_rounded,
            title: 'Check-in Summary',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Your check-ins',
                  myCheckIns.length.toString(),
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Partner\'s',
                  partnerCheckIns.length.toString(),
                  Icons.favorite_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Total',
                  _checkIns.length.toString(),
                  Icons.bar_chart_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _refinedRed, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _lightText,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _dimText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInCard(UserCheckIn checkIn) {
    final isCurrentUser = checkIn.userId == _currentUserId;
    final userName = _getUserName(checkIn.userId);
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isCurrentUser ? _refinedRed : _greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isCurrentUser ? _refinedRed : _greenAccent).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isCurrentUser ? _refinedRed : _greenAccent,
                      _cardVariant,
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Card content
          Expanded(
            child: _CheckInItemCard(
              checkIn: checkIn,
              userName: userName,
              isCurrentUser: isCurrentUser,
              dateFormat: dateFormat,
              getTrendArrow: _getTrendArrow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual check-in card with micro-interactions.
class _CheckInItemCard extends StatefulWidget {
  const _CheckInItemCard({
    required this.checkIn,
    required this.userName,
    required this.isCurrentUser,
    required this.dateFormat,
    required this.getTrendArrow,
  });

  final UserCheckIn checkIn;
  final String userName;
  final bool isCurrentUser;
  final DateFormat dateFormat;
  final String Function(int) getTrendArrow;

  @override
  State<_CheckInItemCard> createState() => _CheckInItemCardState();
}

class _CheckInItemCardState extends State<_CheckInItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: PremiumCard(
          margin: EdgeInsets.zero,
          glowIntensity: widget.isCurrentUser ? 1.2 : 0.8,
          enableInteraction: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isCurrentUser
                          ? _refinedRed.withValues(alpha: 0.2)
                          : _greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isCurrentUser
                            ? _refinedRed.withValues(alpha: 0.3)
                            : _greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isCurrentUser ? _refinedRed : _greenAccent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.checkIn.timeAgo,
                    style: const TextStyle(fontSize: 12, color: _dimText),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scores
              Row(
                children: [
                  _buildScoreBadge('💙', 'Connection', widget.checkIn.connection),
                  const SizedBox(width: 8),
                  _buildScoreBadge('❤️', 'Intimacy', widget.checkIn.intimacy),
                  const SizedBox(width: 8),
                  _buildScoreBadge('☮️', 'Peace', widget.checkIn.peace),
                ],
              ),

              // Notes
              if (widget.checkIn.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    widget.checkIn.notes,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: _bodyGray,
                    ),
                  ),
                ),
              ],

              // Timestamp
              const SizedBox(height: 8),
              Text(
                widget.dateFormat.format(widget.checkIn.timestamp),
                style: const TextStyle(fontSize: 12, color: _dimText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(String emoji, String label, int score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _cardVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              '$score ${widget.getTrendArrow(score)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
