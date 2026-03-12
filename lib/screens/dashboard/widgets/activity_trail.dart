/// Activity Trail card for the dashboard.
///
/// Shows a chronological list of recent activities in the couple space,
/// styled as a card matching the Coming Up and Health cards.
/// Supports pagination with "View older" to load more activities.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/activity.dart';
import '../../../models/moment.dart';
import '../../../models/pulse_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/moment_type_icon.dart';

/// Activity Trail card showing recent space activities with pagination.
///
/// Displays activities in a card with timeline format:
/// - Moment type icons for moment activities (colored by action)
/// - Actor name and action description
/// - Relative timestamp
/// - Tap to navigate (where applicable)
/// - "View older" button to load more activities
class ActivityTrail extends StatefulWidget {
  const ActivityTrail({
    super.key,
    required this.spaceId,
    this.onActivityTap,
    this.initialLimit = 6,
    this.loadMoreCount = 4,
  });

  /// Space ID to load activities for.
  final String spaceId;

  /// Callback when an activity is tapped (for navigation).
  final void Function(Activity activity)? onActivityTap;

  /// Initial number of activities to show.
  final int initialLimit;

  /// Number of activities to load when "View older" is pressed.
  final int loadMoreCount;

  @override
  State<ActivityTrail> createState() => _ActivityTrailState();
}

class _ActivityTrailState extends State<ActivityTrail> {
  final _firestoreService = FirestoreService();
  final _currentUserId = AuthService().currentUser?.uid;

  StreamSubscription<List<Activity>>? _subscription;
  List<Activity> _activities = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentLimit = 6;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _currentLimit = widget.initialLimit;
    _subscribeToActivities();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToActivities() {
    _subscription?.cancel();
    _subscription = _firestoreService
        .watchActivities(
          widget.spaceId,
          limit: _currentLimit + 1,
        ) // +1 to check if there's more
        .listen((activities) {
          if (mounted) {
            setState(() {
              // Check if there are more activities than the current limit
              _hasMore = activities.length > _currentLimit;
              // Only show up to current limit
              _activities = activities.take(_currentLimit).toList();
              _isLoading = false;
              _isLoadingMore = false;
            });
          }
        });
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isLoadingMore = true;
      _currentLimit += widget.loadMoreCount;
    });
    _subscribeToActivities();
  }

  void _handleTap(Activity activity) {
    if (!activity.isNavigable) return;
    HapticFeedback.selectionClick();
    widget.onActivityTap?.call(activity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warmMuted.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'ACTIVITY',
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Content
          if (_isLoading)
            _buildLoadingContent()
          else if (_activities.isEmpty)
            _buildEmptyContent()
          else
            _buildActivityList(),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Activity items
        ...(_activities.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          final isLast = index == _activities.length - 1 && !_hasMore;

          return _ActivityItem(
            activity: activity,
            isLast: isLast,
            currentUserId: _currentUserId,
            onTap: () => _handleTap(activity),
          );
        })),

        // Load more text
        if (_hasMore) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isLoadingMore ? null : _loadMore,
            behavior: HitTestBehavior.opaque,
            child: _isLoadingMore
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.warmMuted,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '+ more activity',
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.cardVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.cardVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.cardVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.warmMuted.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.history_rounded,
            color: AppColors.warmMuted,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'No activity yet',
          style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 13),
        ),
      ],
    );
  }
}

/// Single activity item in the trail.
class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.activity,
    required this.isLast,
    this.currentUserId,
    this.onTap,
  });

  final Activity activity;
  final bool isLast;
  final String? currentUserId;
  final VoidCallback? onTap;

  /// "You" for the current user, otherwise the actor's name.
  String get _displayName =>
      (currentUserId != null && activity.actorId == currentUserId)
      ? 'You'
      : activity.actorName;

  // Slider-based colors for moment activities
  // Red (warm/high) for creation, Blue (cool/low) for deletion, Middle for edit
  static const Color _createColor = AppColors.accentRed; // Red - warm/new
  static const Color _deleteColor =
      AppColors.morningColor; // Blue - cool/removed
  static Color get _editColor =>
      Color.lerp(_deleteColor, _createColor, 0.5)!; // Purple-ish middle

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: activity.isNavigable ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                _buildIcon(),
                const SizedBox(width: 12),

                // Content
                Expanded(child: _buildContent()),

                // Time on the right
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    activity.relativeTime,
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Separator line (unless last item)
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.warmMuted.withValues(alpha: 0.15),
          ),
      ],
    );
  }

  Widget _buildIcon() {
    final color = _getActivityColor();

    // For check-in activities, show a tiny Voronoi mosaic
    if (activity.type == ActivityType.checkin) {
      return _buildCheckinMosaicIcon();
    }

    // For moment activities, always use the moment type icon
    if (activity.type.isMomentActivity) {
      final momentTypeStr = activity.metadata?['momentType'] as String?;
      // Default to 'connect' if no moment type in metadata
      final momentType = momentTypeStr != null
          ? MomentType.fromValue(momentTypeStr)
          : MomentType.connect;

      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: getMomentTypeIconWidget(momentType, size: 14, color: color),
        ),
      );
    }

    // For other activities, use the default icon
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Icon(_getActivityIcon(), color: color, size: 14)),
    );
  }

  /// Check-in icon — mosaic tile SVG on a tinted rounded square,
  /// matching the style of other activity icons.
  Widget _buildCheckinMosaicIcon() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _createColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/mosaic_tile.svg',
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(_createColor, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Check if this is a check-in with scores (multiline display)
    final isCheckinWithScores =
        activity.type == ActivityType.checkin &&
        activity.metadata?['scores'] != null;

    if (isCheckinWithScores) {
      return _buildCheckinContent();
    }

    // Check if this is a moment planned activity with date
    if (activity.type == ActivityType.momentPlanned &&
        activity.metadata?['startDate'] != null) {
      return _buildMomentPlannedContent();
    }

    // Check if this is a moment edited activity with changed fields
    if (activity.type == ActivityType.momentEdited &&
        activity.changedFields.isNotEmpty) {
      return _buildMomentEditedContent();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _displayName,
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: ' ${activity.description}',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Builds moment planned content with date info.
  Widget _buildMomentPlannedContent() {
    final momentName = activity.metadata?['momentName'] as String? ?? '';
    final startDateStr = activity.metadata?['startDate'] as String?;
    final endDateStr = activity.metadata?['endDate'] as String?;

    String dateText = '';
    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      if (endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        dateText =
            '${_formatShortDate(startDate)} - ${_formatShortDate(endDate)}';
      } else {
        dateText = _formatShortDate(startDate);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$_displayName planned ',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: momentName,
                style: GoogleFonts.inter(
                  color: AppColors.warmLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (dateText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            dateText,
            style: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Builds moment edited content showing what was changed.
  Widget _buildMomentEditedContent() {
    final momentName = activity.metadata?['momentName'] as String? ?? '';
    final changedFields = activity.changedFields;

    final formattedFields = changedFields.map((field) {
      switch (field) {
        case 'date':
          return 'Modified dates';
        case 'time':
          return 'Modified time';
        case 'notes':
          return 'Modified notes';
        default:
          return 'Modified $field';
      }
    }).toList();
    final changesText = formattedFields.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$_displayName updated ',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: momentName,
                style: GoogleFonts.inter(
                  color: AppColors.warmLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          changesText,
          style: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 12),
        ),
      ],
    );
  }

  /// Builds check-in specific content with dynamic score badges.
  Widget _buildCheckinContent() {
    final scores = _parseScoresFromMetadata(activity.metadata);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "You checked in"
        Text(
          '$_displayName checked in',
          style: GoogleFonts.inter(
            color: AppColors.warmDim,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),

        // Dynamic score icons coloured by value (blue→red spectrum)
        Row(
          children: [
            for (int i = 0; i < scores.entries.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _buildDynamicScoreIcon(
                scores.entries.elementAt(i).key,
                scores.entries.elementAt(i).value,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Score colour on the blue (low) → red (high) spectrum (1-100 scale).
  Color _scoreColor(int score) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((score - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  Widget _buildDynamicScoreIcon(String attrId, int score) {
    final color = _scoreColor(score);
    final attr = PulseAttribute.fromId(attrId);
    if (attr != null) return attr.buildIcon(color: color, size: 16);
    return Icon(Icons.circle, color: color, size: 16);
  }

  /// Extracts scores from activity metadata. Returns empty on malformed data.
  static Map<String, int> _parseScoresFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    try {
      if (metadata == null || metadata['scores'] is! Map) return {};
      final raw = Map<String, dynamic>.from(metadata['scores'] as Map);
      return raw.map((k, v) {
        if (v is Map) return MapEntry(k, (v['value'] as num).toInt());
        return MapEntry(k, (v as num).toInt());
      });
    } catch (_) {
      return {};
    }
  }

  IconData _getActivityIcon() {
    switch (activity.type) {
      case ActivityType.checkin:
        return Icons
            .donut_large_rounded; // Dotted circle style for health check-in
      case ActivityType.momentPlanned:
      case ActivityType.momentEdited:
      case ActivityType.momentDeleted:
      case ActivityType.momentCompleted:
        // This won't be used since we always use moment type icons for moments
        return Icons.event_rounded;
      case ActivityType.spaceCreated:
        return Icons.home_rounded;
      case ActivityType.spaceJoined:
        return Icons.person_add_rounded;
      case ActivityType.spaceRenamed:
        return Icons.edit_rounded;
      case ActivityType.inviteSent:
        return Icons.send_rounded;
      case ActivityType.inviteAccepted:
        return Icons.handshake_rounded;
    }
  }

  Color _getActivityColor() {
    switch (activity.type) {
      // Moment activities - slider color scheme
      case ActivityType.momentPlanned:
        return _createColor; // Red - warm/new
      case ActivityType.momentDeleted:
        return _deleteColor; // Blue - cool/removed
      case ActivityType.momentEdited:
        return _editColor; // Purple - middle
      case ActivityType.momentCompleted:
        return _createColor; // Red - warm/success

      // Check-in - theme red
      case ActivityType.checkin:
        return AppColors.accentRed;

      // Space activities - purple accent
      case ActivityType.spaceCreated:
      case ActivityType.spaceJoined:
      case ActivityType.spaceRenamed:
      case ActivityType.inviteSent:
      case ActivityType.inviteAccepted:
        return AppColors.accentPurple;
    }
  }
}
