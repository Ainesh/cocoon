/// Moment details bottom sheet showing full moment information.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../models/integration_config.dart';
import '../../models/memory.dart';
import '../../models/moment.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/storage_service.dart';
import '../../utils/date_utils.dart';
import '../../services/firestore_service.dart';
import '../../widgets/emoji_reaction_picker.dart';
import '../../theme/theme.dart';
import '../../widgets/moment_type_icon.dart';
import '../../widgets/painters/circle_progress_painters.dart';

/// Which field triggered the edit action.
enum MomentEditField {
  general, // Swipe up or general edit
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
  required String spaceId,
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
      spaceId: spaceId,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _MomentDetailsContent extends StatefulWidget {
  const _MomentDetailsContent({
    required this.moment,
    required this.spaceId,
    this.onEdit,
    this.onDelete,
  });

  final Moment moment;
  final String spaceId;
  final OnEditCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_MomentDetailsContent> createState() => _MomentDetailsContentState();
}

class _MomentDetailsContentState extends State<_MomentDetailsContent>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  // Shake animation for editing state
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _isHoldingDelete = false;
  int _activeDots = 24; // Total dots, counts down to 0
  Timer? _deleteTimer;
  OverlayEntry? _overlayEntry;
  String? _plannedByName;
  String? _partnerEditingName;
  String? _hintMessage;
  Timer? _hintTimer;
  Moment? _liveMoment; // Updated in real-time when partner edits
  CalendarIntegration? _calendarIntegration;
  bool _isSyncing = false;
  StreamSubscription<List<({String name, DateTime time})>>?
  _presenceSubscription;
  StreamSubscription<DocumentSnapshot>? _momentSubscription;

  // Memory state for unified view
  Memory? _userMemory;
  Memory? _partnerMemory;
  StreamSubscription? _userMemorySub;
  bool _showingPartnerMemory = false;
  final _storageService = StorageService();
  final _thumbUrls = <String>[];
  final _fullUrls = <String>[];

  bool get _isExternal => widget.moment.type == MomentType.external;

  String get _plannedBySubtitle {
    if (_isExternal) {
      return 'Synced from ${widget.moment.createdBy}';
    }
    final name = _plannedByName ?? '';
    final createdAt = widget.moment.createdAt;
    if (createdAt != null) {
      final dateStr = DateFormat('EEEE, MMM d').format(createdAt);
      return 'Planned by $name on $dateStr';
    }
    return 'Planned by $name';
  }

  static const _totalDots = 24;
  static const _totalDurationMs = 3000; // 3 seconds
  static const _msPerDot = _totalDurationMs ~/ _totalDots; // ~125ms per dot

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(
      begin: -0.012,
      end: 0.012,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_shakeController);
    // Sync haptic with each shake direction change
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        HapticFeedback.selectionClick();
      }
    });
    _loadPlannedByName();
    if (!_isExternal) {
      _watchEditingPresence();
      _loadCalendarIntegration();
    }
    if (widget.moment.status == MomentStatus.lived) {
      _loadMemories();
    }
  }

  Future<void> _loadCalendarIntegration() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    try {
      final config = await _firestoreService.getIntegrationConfig(userId);
      if (mounted && config.hasCalendar) {
        setState(() => _calendarIntegration = config.calendar);
      }
    } catch (_) {}
  }

  void _watchEditingPresence() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    // Need spaceId — extract from moment's Firestore path or pass it
    // For now, we get it from the user's profile
    _firestoreService.getUserSpaceId(userId).then((spaceId) {
      if (!mounted || spaceId == null) return;
      // Garbage-collect orphaned presence docs from crashed sessions
      _firestoreService.cleanupStalePresence(
        spaceId: spaceId,
        momentId: widget.moment.id,
      );
      // Watch editing presence
      _presenceSubscription = _firestoreService
          .watchEditingPresence(
            spaceId: spaceId,
            momentId: widget.moment.id,
            excludeUserId: userId,
          )
          .listen((editors) {
            if (mounted) {
              final wasEditing = _partnerEditingName != null;
              final isEditing = editors.isNotEmpty;
              setState(() {
                _partnerEditingName = isEditing ? editors.first.name : null;
              });
              // Start/stop shake (haptic syncs via controller listener)
              if (isEditing && !wasEditing) {
                _shakeController.repeat(reverse: true);
              } else if (!isEditing && wasEditing) {
                _shakeController.stop();
                _shakeController.reset();
              }
            }
          });
      // Watch moment document for live updates (partner edits)
      _momentSubscription = _firestoreService
          .watchMoment(spaceId: spaceId, momentId: widget.moment.id)
          .listen((snapshot) {
            if (!mounted || !snapshot.exists) return;
            final data = snapshot.data() as Map<String, dynamic>?;
            if (data == null) return;
            final updated = Moment.fromJson(snapshot.id, data);
            // Only update if version changed (partner saved)
            if (updated.version != moment.version) {
              setState(() => _liveMoment = updated);
            }
          });
    });
  }

  Future<void> _loadPlannedByName() async {
    if (_isExternal) {
      if (mounted) setState(() => _plannedByName = widget.moment.createdBy);
      return;
    }
    if (widget.moment.createdBy.isEmpty) return;
    final currentUserId = _authService.currentUser?.uid;
    if (widget.moment.createdBy == currentUserId) {
      if (mounted) setState(() => _plannedByName = 'You');
      return;
    }
    final profile = await _firestoreService.getUserProfile(
      widget.moment.createdBy,
    );
    if (mounted && profile != null) {
      setState(() => _plannedByName = profile['name'] as String?);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _presenceSubscription?.cancel();
    _momentSubscription?.cancel();
    _userMemorySub?.cancel();
    _hintTimer?.cancel();
    _deleteTimer?.cancel();
    _deleteTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  Future<void> _loadMemories() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final memoryId = _firestoreService.generateMemoryId(
      spaceId: widget.spaceId,
      momentId: widget.moment.id,
      userId: userId,
    );

    // Ensure user's memory doc exists. It may be missing if:
    // - Partner marked the moment lived (only their memory was created)
    // - Legacy moment marked lived without auto-create
    // Create a minimal empty memory so the unified view can render.
    final existing = await _firestoreService.getMemory(
      spaceId: widget.spaceId,
      memoryId: memoryId,
    );
    if (existing == null && mounted) {
      final emptyMemory = Memory(
        id: memoryId,
        createdBy: userId,
        date: moment.startDate,
        createdAt: DateTime.now(),
        momentId: moment.id,
        momentName: moment.name,
        momentType: moment.type.value,
        momentDate: moment.startDate,
        momentEndDate: moment.endDate,
        momentTimeSlot: moment.timeSlot?.value,
        momentNotes: moment.notes,
      );
      try {
        await _firestoreService.createMemory(
          spaceId: widget.spaceId,
          memory: emptyMemory,
        );
      } catch (_) {
        // Memory creation may fail if doc already exists (race condition)
      }
    }

    if (!mounted) return;

    // Watch user's own memory for real-time updates
    _userMemorySub = _firestoreService
        .watchMemory(widget.spaceId, memoryId)
        .listen((memory) async {
      if (!mounted) return;
      setState(() => _userMemory = memory);
      if (memory != null) {
        await _resolveMemoryPhotos(memory);
      }
    });

    // Load partner's memory (one-time)
    final memories = await _firestoreService.getMemoriesForMoment(
      spaceId: widget.spaceId,
      momentId: widget.moment.id,
    );
    if (!mounted) return;
    final partner = memories.where((m) => m.createdBy != userId).firstOrNull;
    if (partner != null) {
      setState(() => _partnerMemory = partner);
    }
  }

  Future<void> _resolveMemoryPhotos(Memory memory) async {
    if (memory.thumbPaths.isEmpty && memory.photoPaths.isEmpty) {
      if (mounted) setState(() { _thumbUrls.clear(); _fullUrls.clear(); });
      return;
    }
    try {
      final thumbs = await _storageService.resolveUrls(memory.thumbPaths);
      final fulls = await _storageService.resolveUrls(memory.photoPaths);
      if (mounted) {
        setState(() {
          _thumbUrls..clear()..addAll(thumbs);
          _fullUrls..clear()..addAll(fulls);
        });
      }
    } catch (_) {}
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_activeDots > 1) {
        setState(() => _activeDots--);
        // Recreate overlay with new dot count
        _hideDeleteOverlay();
        _showDeleteOverlay();
        HapticFeedback.selectionClick();
      } else {
        // Delete!
        timer.cancel();
        _hideDeleteOverlay();
        HapticFeedback.heavyImpact();
        // Pop first, then call onDelete — avoids context issues
        if (mounted) Navigator.of(context).pop();
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
    if (!mounted) return;
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

  Moment get moment => _liveMoment ?? widget.moment;
  OnEditCallback? get onEdit => widget.onEdit;
  VoidCallback? get onDelete => widget.onDelete;

  void _goToEditScreen([MomentEditField field = MomentEditField.general]) {
    if (onEdit == null) return;
    if (_partnerEditingName != null) {
      _showHint('$_partnerEditingName is editing this moment, please wait');
      return;
    }
    Navigator.of(context).pop();
    onEdit!(field);
  }

  void _onDoubleTap() {
    if (onEdit == null) return;
    if (_partnerEditingName != null) {
      _showHint('$_partnerEditingName is editing this moment, please wait');
    } else {
      _showHint('Hold to edit');
    }
  }

  void _showHint(String message) {
    HapticFeedback.lightImpact();
    _hintTimer?.cancel();
    setState(() => _hintMessage = message);
    _hintTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _hintMessage = null);
    });
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
          color: AppColors.pureBlack,
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
                    if (_plannedByName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _plannedBySubtitle,
                        style: GoogleFonts.inter(
                          color: AppColors.warmMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    // Partner editing indicator — below subtitle
                    if (_partnerEditingName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_partnerEditingName is currently editing',
                        style: GoogleFonts.inter(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Info cards row (long-press to edit)
                    _buildShakeable(_buildInfoRow()),

                    // Notes section — hidden for external moments with no notes
                    if (!_isExternal ||
                        (moment.notes != null && moment.notes!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      _buildShakeable(_buildNotesSection()),
                    ],

                    // Memory section — for past moments
                    if (moment.isPast && !_isExternal) ...[
                      const SizedBox(height: 12),
                      _buildMemorySection(),
                    ],

                    const SizedBox(height: 12),

                    // Action buttons
                    _buildActions(context),
                  ],
                ),
              ),
            ),
            // In-sheet hint message
            if (_hintMessage != null)
              AnimatedOpacity(
                opacity: _hintMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.accentRed,
                  child: Text(
                    _hintMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.pureBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Wraps a widget in a subtle rotation wobble when partner is editing.
  Widget _buildShakeable(Widget child) {
    if (_partnerEditingName == null) return child;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, _) {
        return Transform.rotate(angle: _shakeAnimation.value, child: child);
      },
    );
  }

  Widget _buildTypeBadge() {
    final isPast = moment.isPast;
    final bgColor = isPast ? AppColors.cardVariant : AppColors.accentRed;
    final fgColor = isPast ? AppColors.warmMuted : AppColors.pureBlack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          getMomentTypeIconWidget(
            moment.type,
            size: 24,
            color: fgColor,
          ),
          const SizedBox(height: 6),
          Text(
            moment.type.label,
            style: GoogleFonts.outfit(
              color: fgColor,
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
        onDoubleTap: _onDoubleTap,
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
        Expanded(
          child: wrapWithLongPress(_buildDateCard(), MomentEditField.date),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: wrapWithLongPress(_buildTimeCard(), MomentEditField.time),
        ),
      ],
    );
  }

  Widget _buildEscapeInfoCard() {
    final nights = moment.endDate != null
        ? moment.endDate!.difference(moment.startDate).inDays
        : 0;
    final nightsText = nights == 1 ? '1 night' : '$nights nights';
    final daysToGoInfo = _getEscapeDaysToGoInfo();
    final startDayName = _getDayName(moment.startDate);

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
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Date range with days-to-go badge inline on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dates + day name in column (matching date card structure)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDateShort(moment.startDate)} – ${_formatDateShort(moment.endDate ?? moment.startDate)}',
                    style: GoogleFonts.outfit(
                      color: AppColors.warmLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Day name + nights on same line
                  Text(
                    '$startDayName · $nightsText',
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Two-line badge for days to go
              if (daysToGoInfo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const daysFull = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return daysFull[date.weekday - 1];
  }

  /// Returns (line1, line2) for escape card days to go badge
  (String, String)? _getEscapeDaysToGoInfo() {
    final today = AppDateFormat.todayUtc();
    final diff = moment.startDate.difference(today).inDays;

    if (diff < 0) return ('Started', '');
    if (diff == 0) return ('Today!', '');
    if (diff == 1) return ('Tomorrow', '');
    return ('$diff days', 'to go');
  }

  Widget _buildDateCard() {
    final relativeDateInfo = _getRelativeDateInfo();
    final dateParts = _getDateParts(moment.startDate); // ("Feb 12", "Thursday")

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
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Date (2 lines) with badge on right - aligned heights
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date in two lines
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateParts.$1, // "Feb 12"
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateParts.$2, // "Thursday"
                      style: GoogleFonts.inter(
                        color: AppColors.warmMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Two-line badge - stretches to match text height
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        ],
      ),
    );
  }

  /// Returns (weekday+month, day) for two-line date display
  /// Returns (line1, line2) for date display: ("Feb 12", "Thursday")
  (String, String) _getDateParts(DateTime date) {
    const months = [
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
    const daysFull = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return (
      '${months[date.month - 1]} ${date.day}',
      daysFull[date.weekday - 1],
    );
  }

  Color _getTimeSlotColor(TimeSlot? slot) {
    if (slot == null) return AppColors.warmMuted;
    final index = TimeSlot.values.indexOf(slot);
    final progress = index / (TimeSlot.values.length - 1);
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress) ??
        AppColors.nightColor;
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
    final end = parts[1].trim(); // e.g., "12 PM" or "9 PM"

    // Extract the hour from start (remove AM/PM)
    final startHour = start.replaceAll(RegExp(r'\s*(AM|PM)'), '');

    return '$startHour - $end';
  }

  Widget _buildTimeCard() {
    // Time card for Connect moments - matching date card structure
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
            style: GoogleFonts.outfit(
              color: AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Time slot name on left, icon on right - aligned heights
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time slot name + time range (matching date card)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasTimeSlot ? moment.timeSlot!.label : 'Anytime',
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hasTimeSlot
                          ? _simplifyTimeRange(moment.timeSlot!.timeRange)
                          : 'Flexible',
                      style: GoogleFonts.inter(color: timeColor, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                // Icon on right - stretches to match text height
                Container(
                  width: 36,
                  decoration: BoxDecoration(
                    color: timeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTimeSlotIcon(moment.timeSlot),
                    size: 20,
                    color: timeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (line1, line2) for the date badge.
  /// e.g., ("13 days", "to go") or ("Today", "")
  (String, String) _getRelativeDateInfo() {
    final today = AppDateFormat.todayUtc();
    final diff = moment.startDate.difference(today).inDays;

    if (diff < 0) return ('Past', '');
    if (diff == 0) return ('Today', '');
    if (diff == 1) return ('Tomorrow', '');
    return ('$diff days', 'to go');
  }

  Widget _buildNotesSection() {
    final hasNotes = moment.notes != null && moment.notes!.isNotEmpty;

    return GestureDetector(
      onDoubleTap: _onDoubleTap,
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
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasNotes ? moment.notes! : 'No notes yet. Hold to add.',
              style: AppTypography.bodyMedium(
                color: hasNotes ? AppColors.subtleText : AppColors.warmMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemorySection() {
    final status = moment.status;

    // Past + planned → prompt: Lived it / Missed it
    if (status == MomentStatus.planned) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentRed.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOW WAS IT?',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _onLivedMoment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.accentRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Lived it',
                          style: GoogleFonts.outfit(
                            color: AppColors.accentRed,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _onMissedMoment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.cardVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Missed it',
                          style: GoogleFonts.inter(
                            color: AppColors.warmDim,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Lived → unified memory view with inline editable placeholders
    if (status == MomentStatus.lived) {
      final memory = _showingPartnerMemory ? _partnerMemory : _userMemory;
      return _buildUnifiedMemoryView(memory);
    }

    // Missed → subtle indicator
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.warmMuted, size: 20),
          const SizedBox(width: 10),
          Text(
            'Marked as missed',
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMemoryView(Memory? memory) {
    if (memory == null) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(color: AppColors.accentRed)),
      );
    }

    final userId = _authService.currentUser?.uid;
    final isOwner = memory.createdBy == userId;
    final canEdit = isOwner && !_showingPartnerMemory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Icon(Icons.psychology_rounded, color: AppColors.accentRed, size: 16),
            const SizedBox(width: 6),
            Text(
              _showingPartnerMemory ? "PARTNER'S MEMORY" : 'YOUR MEMORY',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (_partnerMemory != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showingPartnerMemory = !_showingPartnerMemory);
                  if (_showingPartnerMemory && _partnerMemory != null) {
                    _resolveMemoryPhotos(_partnerMemory!);
                  } else if (_userMemory != null) {
                    _resolveMemoryPhotos(_userMemory!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _showingPartnerMemory ? 'See yours' : "Partner's view",
                    style: GoogleFonts.inter(
                      color: AppColors.warmDim,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Photos
        _buildMemoryPhotoField(memory, canEdit),
        const SizedBox(height: 10),

        // Caption
        _buildMemoryTextField(
          value: memory.caption,
          placeholder: 'How was it?',
          icon: Icons.edit_note_rounded,
          canEdit: canEdit,
          onSave: (text) => _saveMemoryField('caption', text),
        ),
        const SizedBox(height: 8),

        // Place
        _buildMemoryTextField(
          value: memory.place,
          placeholder: 'Where were you?',
          icon: Icons.place_outlined,
          canEdit: canEdit,
          onSave: (text) => _saveMemoryField('place', text),
        ),
        const SizedBox(height: 8),

        // Music
        _buildMemoryTextField(
          value: memory.music,
          placeholder: 'A song that reminds you',
          icon: Icons.music_note_outlined,
          canEdit: canEdit,
          onSave: (text) => _saveMemoryField('music', text),
        ),

        // Reactions
        if (memory.reactions.isNotEmpty || !_showingPartnerMemory) ...[
          const SizedBox(height: 12),
          _buildMemoryReactions(memory),
        ],
      ],
    );
  }

  Widget _buildMemoryPhotoField(Memory memory, bool canEdit) {
    if (memory.hasPhotos && _thumbUrls.isNotEmpty) {
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _thumbUrls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _thumbUrls[i],
              width: 80, height: 80, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80, height: 80, color: AppColors.cardVariant,
                child: const Icon(Icons.broken_image, color: AppColors.warmMuted, size: 20),
              ),
            ),
          ),
        ),
      );
    }

    if (!canEdit) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _pickMemoryPhotos(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.cardVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warmMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: AppColors.warmMuted, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add a photo',
              style: GoogleFonts.inter(color: AppColors.warmMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryTextField({
    required String? value,
    required String placeholder,
    required IconData icon,
    required bool canEdit,
    required ValueChanged<String?> onSave,
  }) {
    final hasValue = value != null && value.isNotEmpty;

    return GestureDetector(
      onTap: canEdit ? () => _showFieldEditor(placeholder, value, onSave) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? AppColors.darkCardLight : AppColors.cardVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: !hasValue && canEdit
              ? Border.all(color: AppColors.warmMuted.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: hasValue ? AppColors.warmDim : AppColors.warmMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (value != null && value.isNotEmpty) ? value : placeholder,
                style: GoogleFonts.inter(
                  color: hasValue ? AppColors.warmLight : AppColors.warmMuted,
                  fontSize: 13,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canEdit && !hasValue)
              Icon(Icons.add_rounded, size: 16, color: AppColors.warmMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryReactions(Memory memory) {
    final userId = _authService.currentUser?.uid;
    final myReaction = userId != null ? memory.reactions[userId] : null;
    final partnerReaction = memory.reactions.entries
        .where((e) => e.key != userId)
        .map((e) => e.value)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partnerReaction != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(partnerReaction, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('Partner reacted', style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 12)),
              ],
            ),
          ),
        if (!_showingPartnerMemory)
          EmojiReactionPicker(
            selectedEmoji: myReaction,
            onSelected: (emoji) => _toggleReaction(memory, emoji),
          ),
      ],
    );
  }

  void _showFieldEditor(String label, String? currentValue, ValueChanged<String?> onSave) {
    final controller = TextEditingController(text: currentValue ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.pureBlack,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(color: AppColors.warmLight, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.inter(color: AppColors.warmLight, fontSize: 14),
              maxLines: label.contains('How') ? 3 : 1,
              maxLength: label.contains('How') ? 280 : 100,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: GoogleFonts.inter(color: AppColors.warmMuted),
                border: InputBorder.none,
                counterStyle: TextStyle(color: AppColors.warmMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppColors.warmMuted)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    onSave(text.isEmpty ? null : text);
                    Navigator.pop(ctx);
                  },
                  child: Text('Save', style: TextStyle(color: AppColors.accentRed)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMemoryField(String field, dynamic value) async {
    final memory = _userMemory;
    if (memory == null) return;

    try {
      await _firestoreService.updateMemoryField(
        spaceId: widget.spaceId,
        memoryId: memory.id,
        field: field,
        value: value ?? FieldValue.delete(),
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickMemoryPhotos() async {
    // Defer to the create memory screen for photo management
    // since it handles compression + upload + multi-photo
    final memory = _userMemory;
    if (memory == null) return;
    Navigator.pop(context);
    context.push('/memory/${widget.spaceId}/create', extra: moment);
  }

  Future<void> _toggleReaction(Memory memory, String emoji) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      if (memory.reactions[userId] == emoji) {
        await _firestoreService.removeReaction(
          spaceId: widget.spaceId, memoryId: memory.id, userId: userId,
        );
      } else {
        await _firestoreService.setReaction(
          spaceId: widget.spaceId, memoryId: memory.id, userId: userId, emoji: emoji,
        );
        final profile = await _firestoreService.getUserProfile(userId);
        final userName = profile?['name'] as String? ?? 'Someone';
        await _firestoreService.logMemoryReactionActivity(
          spaceId: widget.spaceId, userId: userId, userName: userName,
          memoryId: memory.id, memoryTitle: memory.displayTitle, emoji: emoji,
        );
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _onLivedMoment() async {
    HapticFeedback.mediumImpact();

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;
      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.markMomentLived(
        spaceId: widget.spaceId,
        moment: moment,
        userId: userId,
        userName: userName,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _onMissedMoment() async {
    final spaceId = widget.spaceId;
    HapticFeedback.lightImpact();

    try {
      await _firestoreService.updateMomentStatus(
        spaceId: spaceId,
        momentId: moment.id,
        status: MomentStatus.missed,
      );

      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final profile = await _firestoreService.getUserProfile(userId);
        final userName = profile?['name'] as String? ?? 'Someone';
        await _firestoreService.logMomentMissedActivity(
          spaceId: spaceId,
          userId: userId,
          userName: userName,
          momentId: moment.id,
          momentName: moment.name,
          momentType: moment.type.value,
          rescheduled: false,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (_calendarIntegration != null && !_isExternal) ...[
          _buildSyncButton(),
          const SizedBox(height: 8),
        ],
        if (onDelete != null && moment.status != MomentStatus.missed)
          _buildHoldToDeleteButton(),
      ],
    );
  }

  Widget _buildSyncButton() {
    final userId = _authService.currentUser?.uid ?? '';
    final isSynced = moment.isSyncedByUser(userId);
    final providerName = _calendarIntegration?.provider == CalendarProvider.google
        ? 'Google Calendar'
        : 'Apple Calendar';
    final label = _isSyncing
        ? 'Syncing...'
        : isSynced
            ? 'Synced to $providerName'
            : 'Sync to $providerName';
    final icon = isSynced ? Icons.check_circle_rounded : Icons.sync_rounded;
    final color = isSynced ? AppColors.warmMuted : AppColors.accentRed;

    return GestureDetector(
      onTap: (isSynced || _isSyncing) ? null : _syncToCalendar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentRed,
                ),
              )
            else
              Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncToCalendar() async {
    if (_calendarIntegration == null || _isSyncing) return;
    setState(() => _isSyncing = true);
    HapticFeedback.mediumImpact();

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final spaceId = await _firestoreService.getUserSpaceId(userId);
    if (spaceId == null || !mounted) {
      setState(() => _isSyncing = false);
      return;
    }

    final calendarService = CalendarService();
    final eventId = await calendarService.syncMoment(
      moment: moment,
      integration: _calendarIntegration!,
      spaceId: spaceId,
      userId: userId,
    );

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (eventId != null) {
      final updatedIds = Map<String, String>.from(
        moment.externalEventIds ?? {},
      )..[userId] = eventId;
      _liveMoment = moment.copyWith(externalEventIds: updatedIds);
      HapticFeedback.heavyImpact();
    } else {
      _showHint('Sync failed — try again');
    }
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
    const months = [
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
            color: AppColors.darkCardLight,
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
