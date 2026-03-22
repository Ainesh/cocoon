/// Reusable memory card and slider components extracted from the memories tab.
///
/// - [MemoryMemberCard] — a single member's memory detail card.
/// - [MemoryTag] — a compact tag chip (icon + text).
/// - [SnapScrollPhysics] — custom snap-to-item scroll physics.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/memory.dart';
import '../models/pulse_config.dart';
import '../models/user_checkin.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_utils.dart';

// =============================================================================
// MemoryMemberCard — individual memory's non-image fields
// =============================================================================

class MemoryMemberCard extends StatefulWidget {
  const MemoryMemberCard({
    super.key,
    required this.memory,
    required this.creatorName,
    required this.spaceId,
    this.isCurrentUser = false,
  });

  final Memory memory;
  final String creatorName;
  final String spaceId;
  final bool isCurrentUser;

  @override
  State<MemoryMemberCard> createState() => _MemoryMemberCardState();
}

class _MemoryMemberCardState extends State<MemoryMemberCard> {
  Map<String, int>? _checkinScores;

  @override
  void initState() {
    super.initState();
    _fetchCheckinScores();
  }

  @override
  void didUpdateWidget(MemoryMemberCard old) {
    super.didUpdateWidget(old);
    if (old.memory.checkinId != widget.memory.checkinId) {
      _fetchCheckinScores();
    }
  }

  Future<void> _fetchCheckinScores() async {
    final checkinId = widget.memory.checkinId;
    if (checkinId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('checkins')
          .doc(checkinId)
          .get();
      if (!mounted || !doc.exists) return;
      final checkin = UserCheckIn.fromFirestore(doc);
      setState(() => _checkinScores = checkin.scores);
    } catch (_) {
      // Scores unavailable — leave null
    }
  }

  static Color _scoreColor(int score) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((score - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isCurrentUser
                ? 'YOUR MEMORY'
                : "${widget.creatorName}'s memory".toUpperCase(),
            style: GoogleFonts.outfit(
              color: AppColors.accentRed,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (m.hasCaption)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                m.caption!,
                style: AppTypography.bodyMedium(color: AppColors.warmLight),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (m.hasMusic)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child:
                  MemoryTag(icon: Icons.music_note_outlined, text: m.music!),
            ),

          if (m.hasCheckin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _checkinScores != null && _checkinScores!.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0;
                            i < _checkinScores!.entries.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          _buildScoreIcon(
                            _checkinScores!.entries.elementAt(i).key,
                            _checkinScores!.entries.elementAt(i).value,
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Checked in',
                          style: GoogleFonts.inter(
                            color: AppColors.warmDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),

          if (!m.hasCheckin && widget.isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/checkin/${widget.spaceId}');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 14,
                      color: AppColors.accentRed.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'How did it feel? Check in',
                      style: GoogleFonts.inter(
                        color: AppColors.accentRed.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(
                  AppDateFormat.compact(m.createdAt),
                  style: GoogleFonts.inter(
                    color: AppColors.warmDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (m.isEdited) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· edited ${AppDateFormat.compact(m.updatedAt!)}',
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIcon(String attrId, int score) {
    final color = _scoreColor(score);
    final attr = PulseAttribute.fromId(attrId);
    if (attr != null) return attr.buildIcon(color: color, size: 16);
    return Icon(Icons.circle, color: color, size: 16);
  }
}

// =============================================================================
// MemoryTag — compact tag chip
// =============================================================================

class MemoryTag extends StatelessWidget {
  const MemoryTag({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.warmMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.warmDim,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SnapScrollPhysics — snaps to left-aligned item boundaries
// =============================================================================

class SnapScrollPhysics extends ScrollPhysics {
  const SnapScrollPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  static final SpringDescription _snapSpring =
      SpringDescription(mass: 0.5, stiffness: 300, damping: 22);

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _targetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page = page.floorToDouble();
    } else if (velocity > tolerance.velocity) {
      page = page.ceilToDouble();
    } else {
      page = page.roundToDouble();
    }
    return (page * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _targetPixels(position, toleranceFor(position), velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
          _snapSpring, position.pixels, target, velocity);
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
