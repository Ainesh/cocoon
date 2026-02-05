/// Moment details bottom sheet showing full moment information.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/moment.dart';
import '../../theme/theme.dart';
import '../../widgets/moment_type_icon.dart';
import '../../widgets/painters/circle_progress_painters.dart';

/// Which field triggered the edit action.
enum MomentEditField {
  general,  // Swipe up or general edit
  date,
  time,
  notes,
}

/// Callback type for edit action with field info.
typedef OnEditCallback = void Function(MomentEditField field);

/// Shows moment details in a modal bottom sheet.
void showMomentDetailsSheet({
  required BuildContext context,
  required Moment moment,
  OnEditCallback? onEdit,
  VoidCallback? onDelete,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _MomentDetailsContent(
      moment: moment,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _MomentDetailsContent extends StatefulWidget {
  const _MomentDetailsContent({
    required this.moment,
    this.onEdit,
    this.onDelete,
  });

  final Moment moment;
  final OnEditCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_MomentDetailsContent> createState() => _MomentDetailsContentState();
}

class _MomentDetailsContentState extends State<_MomentDetailsContent> {
  bool _isHoldingDelete = false;
  int _activeDots = 24; // Total dots, counts down to 0
  Timer? _deleteTimer;
  OverlayEntry? _overlayEntry;
  
  static const _totalDots = 24;
  static const _totalDurationMs = 3000; // 3 seconds
  static const _msPerDot = _totalDurationMs ~/ _totalDots; // ~125ms per dot

  @override
  void dispose() {
    _cancelDelete();
    super.dispose();
  }

  void _startDelete() {
    setState(() {
      _isHoldingDelete = true;
      _activeDots = _totalDots;
    });
    HapticFeedback.mediumImpact();
    _showDeleteOverlay();
    
    // Timer fires for each dot
    _deleteTimer = Timer.periodic(Duration(milliseconds: _msPerDot), (timer) {
      if (_activeDots > 1) {
        setState(() => _activeDots--);
        // Recreate overlay with new dot count
        _hideDeleteOverlay();
        _showDeleteOverlay();
        HapticFeedback.selectionClick(); // Light haptic for each dot
      } else {
        // Delete!
        timer.cancel();
        _hideDeleteOverlay();
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
        widget.onDelete?.call();
      }
    });
  }

  void _cancelDelete() {
    _deleteTimer?.cancel();
    _deleteTimer = null;
    _hideDeleteOverlay();
    if (mounted) {
      setState(() {
        _isHoldingDelete = false;
        _activeDots = _totalDots;
      });
    }
  }

  void _showDeleteOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _DeleteCountdownOverlay(
        activeDots: _activeDots,
        totalDots: _totalDots,
        momentName: widget.moment.name,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDeleteOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Moment get moment => widget.moment;
  OnEditCallback? get onEdit => widget.onEdit;
  VoidCallback? get onDelete => widget.onDelete;

  void _goToEditScreen([MomentEditField field = MomentEditField.general]) {
    if (onEdit == null) return;
    Navigator.of(context).pop();
    onEdit!(field);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dy;
        // Swipe down to close
        if (velocity > 300) {
          Navigator.of(context).pop();
        }
        // Swipe up to go to edit screen
        else if (velocity < -300 && onEdit != null) {
          HapticFeedback.mediumImpact();
          _goToEditScreen();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle (swipe up hint)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Type badge with icon
                    _buildTypeBadge(),
                    const SizedBox(height: 20),
                    
                    // Moment name - large and prominent
                    Text(
                      moment.name,
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Info cards row (long-press to edit)
                    _buildInfoRow(),
                    
                    // Notes section (always show, long-press to edit)
                    const SizedBox(height: 20),
                    _buildNotesSection(),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    _buildActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.accentRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          getMomentTypeIconWidget(moment.type, size: 24, color: AppColors.pureBlack),
          const SizedBox(height: 6),
          Text(
            moment.type.label,
            style: GoogleFonts.outfit(
              color: AppColors.pureBlack,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    // Long-press any card to go to edit screen with that field focused
    Widget wrapWithLongPress(Widget child, MomentEditField field) {
      return GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _goToEditScreen(field);
        },
        child: child,
      );
    }

    // Escape: single merged card with dates + nights
    if (moment.type == MomentType.escape) {
      return wrapWithLongPress(_buildEscapeInfoCard(), MomentEditField.date);
    }
    
    // Celebrate: just the date card (full width)
    if (moment.type == MomentType.celebrate) {
      return wrapWithLongPress(_buildDateCard(), MomentEditField.date);
    }
    
    // Connect: two-card layout (date + time)
    return Row(
      children: [
        Expanded(child: wrapWithLongPress(_buildDateCard(), MomentEditField.date)),
        const SizedBox(width: 12),
        Expanded(child: wrapWithLongPress(_buildTimeCard(), MomentEditField.time)),
      ],
    );
  }

  Widget _buildEscapeInfoCard() {
    final nights = moment.endDate != null 
        ? moment.endDate!.difference(moment.startDate).inDays 
        : 0;
    final nightsText = nights == 1 ? '1 night' : '$nights nights';
    final daysToGoInfo = _getEscapeDaysToGoInfo();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'DATES',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Date range with days-to-go badge inline on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dates text
              Text(
                '${_formatDateShort(moment.startDate)} – ${_formatDateShort(moment.endDate ?? moment.startDate)}',
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Two-line badge for days to go
              if (daysToGoInfo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        daysToGoInfo.$1,
                        style: GoogleFonts.inter(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (daysToGoInfo.$2.isNotEmpty)
                        Text(
                          daysToGoInfo.$2,
                          style: GoogleFonts.inter(
                            color: AppColors.accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          // Nights text below dates
          const SizedBox(height: 8),
          Text(
            nightsText,
            style: GoogleFonts.inter(
              color: AppColors.accentRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Returns (line1, line2) for escape card days to go badge
  (String, String)? _getEscapeDaysToGoInfo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(moment.startDate.year, moment.startDate.month, moment.startDate.day);
    final diff = startDate.difference(today).inDays;
    
    if (diff < 0) return ('Started', '');
    if (diff == 0) return ('Today!', '');
    if (diff == 1) return ('Tomorrow', '');
    return ('$diff days', 'to go');
  }

  Widget _buildDateCard() {
    final relativeDateInfo = _getRelativeDateInfo();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'DATE',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Date with badge inline on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date text
              Text(
                _formatDateFull(moment.startDate),
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Two-line badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relativeDateInfo.$1,
                      style: GoogleFonts.inter(
                        color: AppColors.accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (relativeDateInfo.$2.isNotEmpty)
                      Text(
                        relativeDateInfo.$2,
                        style: GoogleFonts.inter(
                          color: AppColors.accentRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTimeSlotColor(TimeSlot? slot) {
    if (slot == null) return AppColors.warmMuted;
    final index = TimeSlot.values.indexOf(slot);
    final progress = index / (TimeSlot.values.length - 1);
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress) ?? AppColors.nightColor;
  }

  IconData _getTimeSlotIcon(TimeSlot? slot) {
    return switch (slot) {
      TimeSlot.morning => Icons.wb_sunny_rounded,
      TimeSlot.afternoon => Icons.light_mode_rounded,
      TimeSlot.evening => Icons.wb_twilight_rounded,
      TimeSlot.night => Icons.dark_mode_rounded,
      null => Icons.schedule_rounded,
    };
  }

  /// Simplifies time range: "5 PM - 9 PM" → "5 - 9 PM"
  String _simplifyTimeRange(String timeRange) {
    // Handle formats like "6 AM - 12 PM", "5 PM - 9 PM"
    final parts = timeRange.split(' - ');
    if (parts.length != 2) return timeRange;
    
    final start = parts[0].trim(); // e.g., "6 AM" or "5 PM"
    final end = parts[1].trim();   // e.g., "12 PM" or "9 PM"
    
    // Extract the hour from start (remove AM/PM)
    final startHour = start.replaceAll(RegExp(r'\s*(AM|PM)'), '');
    
    return '$startHour - $end';
  }

  Widget _buildTimeCard() {
    // Time card for Connect moments - icon and time on right side
    final timeColor = _getTimeSlotColor(moment.timeSlot);
    final hasTimeSlot = moment.timeSlot != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'TIME',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Time slot name with icon and time on right
          Row(
            children: [
              // Time slot name on left
              Expanded(
                child: Text(
                  hasTimeSlot ? moment.timeSlot!.label : 'Anytime',
                  style: GoogleFonts.outfit(
                    color: AppColors.warmLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Icon and time range on right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: timeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTimeSlotIcon(moment.timeSlot),
                      size: 18,
                      color: timeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasTimeSlot ? _simplifyTimeRange(moment.timeSlot!.timeRange) : 'Flexible',
                    style: GoogleFonts.inter(
                      color: timeColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns (line1, line2) for the date badge.
  /// e.g., ("13 days", "to go") or ("Today", "")
  (String, String) _getRelativeDateInfo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final momentDate = DateTime(moment.startDate.year, moment.startDate.month, moment.startDate.day);
    final diff = momentDate.difference(today).inDays;
    
    if (diff < 0) return ('Past', '');
    if (diff == 0) return ('Today', '');
    if (diff == 1) return ('Tomorrow', '');
    return ('$diff days', 'to go');
  }

  Widget _buildNotesSection() {
    final hasNotes = moment.notes != null && moment.notes!.isNotEmpty;
    
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _goToEditScreen(MomentEditField.notes);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOTES',
              style: GoogleFonts.inter(
                color: AppColors.warmMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasNotes ? moment.notes! : 'Nothing added here',
              style: GoogleFonts.inter(
                color: hasNotes ? AppColors.warmDim : AppColors.warmMuted,
                fontSize: 14,
                height: 1.5,
                fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (onDelete == null) return const SizedBox.shrink();
    return _buildHoldToDeleteButton();
  }

  Widget _buildHoldToDeleteButton() {
    // Use accentRed to match ActionButton (Plan a moment, Check in)
    const buttonColor = AppColors.accentRed;
    
    // When held: bg = buttonColor, text/icon = black (matching ActionButton pattern)
    final bgColor = _isHoldingDelete ? buttonColor : AppColors.darkCardLight;
    final fgColor = _isHoldingDelete ? AppColors.pureBlack : buttonColor;
    
    return GestureDetector(
      onLongPressStart: (_) => _startDelete(),
      onLongPressEnd: (_) => _cancelDelete(),
      onLongPressCancel: _cancelDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isHoldingDelete ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hold to cancel',
              style: GoogleFonts.outfit(
                color: fgColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDateFull(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

/// Overlay shown while holding the delete button
class _DeleteCountdownOverlay extends StatelessWidget {
  const _DeleteCountdownOverlay({
    required this.activeDots,
    required this.totalDots,
    required this.momentName,
  });

  final int activeDots;
  final int totalDots;
  final String momentName;

  Color get _currentColor {
    // activeDots 24 → 0.0 (red), activeDots 0 → 1.0 (blue)
    final t = 1.0 - (activeDots / totalDots);
    return Color.lerp(AppColors.nightColor, AppColors.morningColor, t)!;
  }

  double get _progress {
    // Progress: activeDots/totalDots (1.0 when full, 0.0 when empty)
    return activeDots / totalDots;
  }

  int get _displayCountdown {
    // Convert dots to seconds (24 dots = 3s, 16 dots = 2s, 8 dots = 1s)
    return ((activeDots / totalDots) * 3).ceil().clamp(1, 3);
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heading
              Text(
                'Cancelling permanently',
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              // Dotted circle with timer
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dotted circle progress (starts full, empties dot by dot)
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: DottedCircleProgressPainter(
                        progress: _progress,
                        activeColor: color,
                        inactiveColor: color.withValues(alpha: 0.15),
                        dotCount: totalDots,
                        dotRadius: 3.0,
                      ),
                    ),
                    // Countdown number (color matches dots)
                    Text(
                      '$_displayCountdown',
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Moment name
              Text(
                momentName,
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Helper text - subtle
              Text(
                'Like it never happened',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
