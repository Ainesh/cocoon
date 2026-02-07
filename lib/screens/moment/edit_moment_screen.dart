/// Edit Moment screen for Cocoon app.
///
/// Allows users to edit existing moments. The moment type and name
/// cannot be changed - user must cancel and create a new one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/moment.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/active_card.dart';
import '../../widgets/moment_type_icon.dart';
import '../../widgets/painters/circle_progress_painters.dart';
import '../../widgets/slide_to_action.dart';

/// Which field to auto-focus when entering edit mode.
enum EditMomentFocus {
  none,
  date,
  time,
  notes,
}

/// Edit Moment screen for modifying existing moments.
class EditMomentScreen extends StatefulWidget {
  const EditMomentScreen({
    super.key,
    required this.spaceId,
    required this.moment,
    this.initialFocus = EditMomentFocus.none,
  });

  final String spaceId;
  final Moment moment;
  final EditMomentFocus initialFocus;

  @override
  State<EditMomentScreen> createState() => _EditMomentScreenState();
}

class _EditMomentScreenState extends State<EditMomentScreen> {
  // Services
  final _firestoreService = FirestoreService();

  // Form state - initialized from existing moment
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TimeSlot? _selectedTimeSlot;
  late TextEditingController _notesController;
  final _notesFocusNode = FocusNode();

  // UI state
  bool _isSubmitting = false;
  double? _dragPosition; // For time slider stretchy effect
  
  // Delete state
  bool _isHoldingDelete = false;
  int _activeDots = 24;
  Timer? _deleteTimer;
  OverlayEntry? _overlayEntry;
  
  static const _totalDots = 24;
  static const _totalDurationMs = 3000;
  static const _msPerDot = _totalDurationMs ~/ _totalDots;

  @override
  void initState() {
    super.initState();
    // Initialize from existing moment
    _startDate = widget.moment.startDate;
    _endDate = widget.moment.endDate;
    _selectedTimeSlot = widget.moment.timeSlot;
    _notesController = TextEditingController(text: widget.moment.notes ?? '');
    _notesFocusNode.addListener(() => setState(() {}));
    
    // Handle initial focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialFocus();
    });
  }
  
  void _handleInitialFocus() {
    switch (widget.initialFocus) {
      case EditMomentFocus.date:
        if (moment.type == MomentType.escape) {
          _pickBothDates();
        } else {
          _pickStartDate();
        }
        break;
      case EditMomentFocus.notes:
        _notesFocusNode.requestFocus();
        break;
      case EditMomentFocus.time:
      case EditMomentFocus.none:
        // Time doesn't need special focus, none means no action
        break;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    _cancelDelete();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  Moment get moment => widget.moment;
  
  bool get _hasChanges {
    if (_startDate != moment.startDate) return true;
    if (_endDate != moment.endDate) return true;
    if (_selectedTimeSlot != moment.timeSlot) return true;
    if (_notesController.text.trim() != (moment.notes ?? '')) return true;
    return false;
  }

  bool get _canSubmit {
    if (!_hasChanges) return false;
    if (_startDate == null) return false;
    if (moment.type == MomentType.escape && _endDate == null) return false;
    if (moment.type == MomentType.connect && _selectedTimeSlot == null) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Delete Logic (same as MDS)
  // ---------------------------------------------------------------------------

  void _startDelete() {
    _dismissKeyboard();
    setState(() {
      _isHoldingDelete = true;
      _activeDots = _totalDots;
    });
    HapticFeedback.mediumImpact();
    _showDeleteOverlay();
    
    _deleteTimer = Timer.periodic(Duration(milliseconds: _msPerDot), (timer) {
      if (_activeDots > 1) {
        setState(() => _activeDots--);
        _hideDeleteOverlay();
        _showDeleteOverlay();
        HapticFeedback.selectionClick();
      } else {
        timer.cancel();
        _hideDeleteOverlay();
        HapticFeedback.heavyImpact();
        _performDelete();
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
        momentName: moment.name,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDeleteOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _performDelete() async {
    try {
      await _firestoreService.deleteMoment(
        spaceId: widget.spaceId,
        momentId: moment.id,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _dismissKeyboard() => FocusScope.of(context).unfocus();
  
  /// Attempt to go back - shows confirmation if there are unsaved changes
  Future<void> _handleBack() async {
    if (_hasChanges) {
      final shouldDiscard = await _showDiscardChangesDialog();
      if (shouldDiscard != true) return;
    }
    if (mounted) context.pop(moment);
  }
  
  /// Shows a confirmation dialog when user has unsaved changes
  Future<bool?> _showDiscardChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard changes?',
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes that will be lost.',
          style: GoogleFonts.inter(
            color: AppColors.warmDim,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep editing',
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Discard',
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate() async {
    _dismissKeyboard();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: _datePickerTheme,
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickBothDates() async {
    _dismissKeyboard();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.lightImpact();
    await _showDateRangePicker();
  }

  Future<void> _showDateRangePicker({DateTime? initialStart}) async {
    final now = DateTime.now();
    final initialRange = initialStart != null
        ? DateTimeRange(start: initialStart, end: _endDate ?? initialStart.add(const Duration(days: 2)))
        : _startDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate ?? _startDate!.add(const Duration(days: 2)))
            : DateTimeRange(start: now, end: now.add(const Duration(days: 2)));

    final result = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      saveText: 'CONFIRM',
      builder: _datePickerTheme,
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.accentRed,
          onPrimary: AppColors.pureBlack,
          surface: AppColors.darkCardLight,
          onSurface: AppColors.warmLight,
          primaryContainer: AppColors.accentRed.withValues(alpha: 0.2),
        ), dialogTheme: DialogThemeData(backgroundColor: AppColors.darkCard),
      ),
      child: child!,
    );
  }

  void _selectTimeSlot(TimeSlot slot) {
    _dismissKeyboard();
    HapticFeedback.selectionClick();
    setState(() => _selectedTimeSlot = slot);
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      await _firestoreService.updateMoment(
        spaceId: widget.spaceId,
        momentId: moment.id,
        startDate: _startDate!,
        endDate: _endDate,
        timeSlot: _selectedTimeSlot,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      
      // Create updated moment to return
      final updatedMoment = Moment(
        id: moment.id,
        createdBy: moment.createdBy,
        name: moment.name,
        type: moment.type,
        startDate: _startDate!,
        endDate: _endDate,
        timeSlot: _selectedTimeSlot,
        repeatSchedule: moment.repeatSchedule,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: moment.createdAt,
        updatedAt: DateTime.now(),
      );
      
      HapticFeedback.heavyImpact();
      if (mounted) {
        // Pop and return the updated moment so MDS can be re-opened
        context.pop(updatedMoment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept system back button/gesture
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: GestureDetector(
        onTap: _dismissKeyboard,
        // Only horizontal swipe (left to right) should close
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            HapticFeedback.lightImpact();
            _handleBack();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.pureBlack,
          appBar: AppBar(
            backgroundColor: AppColors.pureBlack,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.warmLight),
              onPressed: _handleBack,
            ),
          title: Text(
            'Edit Moment',
            style: GoogleFonts.outfit(
              color: AppColors.warmLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Moment Type Badge (non-editable)
              _buildTypeBadge(),
              const SizedBox(height: 16),
              
              // Moment Name (non-editable)
              Text(
                moment.name,
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Helper text - cannot change type/name
              Text(
                'Type and name cannot be changed.\nCancel this moment and plan a new one.',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Date Card
              _buildDateCard(),
              
              // Time Card (Connect only)
              if (moment.type == MomentType.connect) ...[
                const SizedBox(height: 16),
                _buildTimeCard(),
              ],
              
              // Notes Card
              const SizedBox(height: 16),
              _buildNotesCard(),
              
              // Extra padding to account for sticky bottom buttons
              const SizedBox(height: 120),
            ],
          ),
        ),
        // Sticky bottom buttons
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slide to Save (only when changes exist)
                if (_canSubmit) ...[
                  SlideToAction(
                    label: 'Slide to save',
                    loadingLabel: 'Saving...',
                    onConfirm: _submit,
                    isLoading: _isSubmitting,
                    enabled: _canSubmit && !_isSubmitting,
                  ),
                  const SizedBox(height: 12),
                ],
                // Hold to Delete (always visible)
                _buildHoldToDeleteButton(),
              ],
            ),
          ),
        ),
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

  Widget _buildDateCard() {
    final isEscape = moment.type == MomentType.escape;
    final hasDate = _startDate != null;
    
    return GestureDetector(
      onTap: isEscape ? _pickBothDates : _pickStartDate,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: ActiveCard(
          heading: isEscape ? 'Dates' : 'Date',
          isActive: hasDate,
          child: hasDate 
              ? (isEscape ? _buildEscapeDateDisplay() : _buildSingleDateDisplay())
              : _buildDatePlaceholder(),
        ),
      ),
    );
  }

  Widget _buildSingleDateDisplay() {
    return Text(
      _formatDate(_startDate!),
      style: AppTypography.bodyMedium(color: AppColors.subtleText),
    );
  }

  Widget _buildEscapeDateDisplay() {
    final nights = _endDate != null 
        ? _endDate!.difference(_startDate!).inDays 
        : 0;
    final nightsText = nights == 1 ? '1 night' : '$nights nights';
    
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_formatDate(_startDate!)} – ${_formatDate(_endDate ?? _startDate!)}',
            style: AppTypography.bodyMedium(color: AppColors.subtleText),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            nightsText,
            style: GoogleFonts.inter(
              color: AppColors.accentRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePlaceholder() {
    return Text(
      'Tap to select date',
      style: GoogleFonts.inter(
        color: AppColors.warmMuted,
        fontSize: 14,
      ),
    );
  }

  Color _getTimeSlotColor(int index) {
    final progress = index / (TimeSlot.values.length - 1);
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress) ?? AppColors.nightColor;
  }
  
  Color _getTimeSlotColorFromProgress(double progress) {
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress.clamp(0.0, 1.0)) ?? AppColors.nightColor;
  }

  Widget _buildTimeCard() {
    final hasTime = _selectedTimeSlot != null;
    
    return ActiveCard(
      heading: 'Time',
      isActive: hasTime,
      helperText: !hasTime ? 'What time of day?' : null,
      hideHelperWhenActive: true,
      shrinkWhenActive: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected time label - matching Date card style
          if (hasTime) ...[
            Text(
              _selectedTimeSlot!.label,
              style: AppTypography.bodyMedium(color: AppColors.subtleText),
            ),
            const SizedBox(height: 12),
          ],
          // Slider
          _buildTimeSlotSlider(),
        ],
      ),
    );
  }

  Widget _buildTimeSlotSlider() {
    final slots = TimeSlot.values;
    final selectedIndex = _selectedTimeSlot != null 
        ? slots.indexOf(_selectedTimeSlot!) 
        : 0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / slots.length;
        final totalWidth = constraints.maxWidth;
        final padding = 4.0;
        final baseWidth = slotWidth - (padding * 2);
        
        // Selected slot center position
        final selectedCenter = (selectedIndex + 0.5) * slotWidth;
        final isDragging = _dragPosition != null;
        
        // Calculate stretchy highlight bounds
        double highlightLeft;
        double highlightWidth;
        double colorProgress;
        
        if (isDragging) {
          final dragX = _dragPosition!;
          // Stretch from selected slot toward drag position
          if (dragX < selectedCenter) {
            // Dragging left - stretch left edge
            highlightLeft = dragX - baseWidth * 0.4;
            highlightWidth = (selectedCenter + baseWidth * 0.4) - highlightLeft;
          } else {
            // Dragging right - stretch right edge  
            highlightLeft = selectedCenter - baseWidth * 0.4;
            highlightWidth = (dragX + baseWidth * 0.4) - highlightLeft;
          }
          // Clamp bounds
          highlightLeft = highlightLeft.clamp(padding, totalWidth - baseWidth - padding);
          highlightWidth = highlightWidth.clamp(baseWidth, totalWidth - padding * 2);
          // Color based on drag position
          colorProgress = (dragX / totalWidth).clamp(0.0, 1.0);
        } else {
          // Snapped to selected slot
          highlightLeft = selectedIndex * slotWidth + padding;
          highlightWidth = baseWidth;
          colorProgress = selectedIndex / (slots.length - 1);
        }
        
        return GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() => _dragPosition = details.localPosition.dx.clamp(0, totalWidth));
          },
          onHorizontalDragUpdate: (details) {
            final pos = details.localPosition.dx.clamp(0.0, totalWidth);
            setState(() => _dragPosition = pos);
            
            // Snap selection at slot centers
            final index = (pos / slotWidth).floor().clamp(0, slots.length - 1);
            if (_selectedTimeSlot != slots[index]) {
              HapticFeedback.selectionClick();
              _selectTimeSlot(slots[index]);
            }
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragPosition = null);
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Stretchy highlight - smooth following and snap back
                AnimatedPositioned(
                  duration: Duration(milliseconds: isDragging ? 60 : 280),
                  curve: Curves.easeOut,
                  left: highlightLeft,
                  top: padding,
                  bottom: padding,
                  width: highlightWidth,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: isDragging ? 60 : 280),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: _getTimeSlotColorFromProgress(colorProgress),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _getTimeSlotColorFromProgress(colorProgress).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
                // Time slot icons
                Row(
                  children: slots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final slot = entry.value;
                    final isSelected = _selectedTimeSlot == slot;
                    
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _selectTimeSlot(slot);
                          setState(() => _dragPosition = null);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Icon(
                            _getTimeSlotIcon(slot),
                            size: 22,
                            color: isSelected 
                                ? AppColors.pureBlack 
                                : _getTimeSlotColor(index).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  IconData _getTimeSlotIcon(TimeSlot slot) {
    return switch (slot) {
      TimeSlot.morning => Icons.wb_sunny_rounded,
      TimeSlot.afternoon => Icons.light_mode_rounded,
      TimeSlot.evening => Icons.wb_twilight_rounded,
      TimeSlot.night => Icons.dark_mode_rounded,
    };
  }

  Widget _buildNotesCard() {
    final hasNotes = _notesController.text.trim().isNotEmpty;
    final isFocused = _notesFocusNode.hasFocus;
    final isActive = hasNotes || isFocused;
    
    return GestureDetector(
      onTap: () => _notesFocusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: ActiveCard(
        heading: 'Notes',
        isActive: isActive,
        helperText: !isActive ? 'Space for your thoughts' : null,
        hideHelperWhenActive: true,
        shrinkWhenActive: true,
        showBorder: isFocused,
        child: TextField(
          controller: _notesController,
          focusNode: _notesFocusNode,
          style: AppTypography.bodyMedium(color: AppColors.subtleText),
          cursorColor: AppColors.accentRed,
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: 15,
          minLines: 1,
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
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
    final t = 1.0 - (activeDots / totalDots);
    return Color.lerp(AppColors.nightColor, AppColors.morningColor, t)!;
  }

  double get _progress => activeDots / totalDots;

  int get _displayCountdown => ((activeDots / totalDots) * 3).ceil().clamp(1, 3);

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
              Text(
                'Cancelling permanently',
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
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
