/// Event display cards for the dashboard.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/space_event.dart';
import '../../../theme/theme.dart';

/// Card showing today's or upcoming event.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.events,
    required this.index,
    this.onAddEvent,
  });

  /// All upcoming events.
  final List<SpaceEvent> events;
  
  /// 0 for "Today" card, 1 for "Next" card.
  final int index;
  
  /// Callback when user taps to add event (empty state).
  final VoidCallback? onAddEvent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (index == 0) {
      return _buildTodayCard(today);
    }
    return _buildNextCard(today);
  }

  Widget _buildTodayCard(DateTime today) {
    final todayEvents = events.where((e) {
      final eventDay = DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day);
      return eventDay.isAtSameMomentAs(today);
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warmMuted.withValues(alpha: 0.15), width: 1),
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
          children: [
            Text(
              'Today',
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
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
                  color: AppColors.warmLight,
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
                  color: AppColors.warmDim,
                  fontSize: 13,
                ),
              ),
            ] else
              Text(
                'Nothing planned',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextCard(DateTime today) {
    final futureEvents = events.where((e) {
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
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warmMuted.withValues(alpha: 0.15), width: 1),
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
            children: [
              Text(
                daysUntil == 1 ? 'Tomorrow' : DateFormat('EEE, MMM d').format(event.scheduledAt),
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                event.title,
                style: GoogleFonts.inter(
                  color: AppColors.warmLight,
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
                  color: AppColors.warmDim,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state - add event
    return GestureDetector(
      onTap: onAddEvent,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.15),
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
                  color: AppColors.warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                'Plan something',
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Check-in button card.
class CheckInCard extends StatelessWidget {
  const CheckInCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.12),
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
                color: AppColors.accentRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.play_circle_filled_rounded,
              color: AppColors.accentRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Upcoming event list item.
class UpcomingEventItem extends StatelessWidget {
  const UpcomingEventItem({
    super.key,
    required this.event,
  });

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(event.scheduledAt.year, event.scheduledAt.month, event.scheduledAt.day);
    final daysUntil = eventDay.difference(today).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              event.type == EventType.dateNight ? Icons.dinner_dining_rounded : Icons.event_rounded,
              color: AppColors.accentRed,
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
                    color: AppColors.warmLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE, MMM d • HH:mm').format(event.scheduledAt),
                  style: GoogleFonts.inter(
                    color: AppColors.warmMuted,
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
                  ? AppColors.accentRed.withValues(alpha: 0.15) 
                  : AppColors.darkCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              daysUntil == 0
                  ? 'Today'
                  : daysUntil == 1
                      ? 'Tomorrow'
                      : '${daysUntil}d',
              style: GoogleFonts.inter(
                color: daysUntil <= 1 ? AppColors.accentRed : AppColors.warmDim,
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
