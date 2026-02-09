/// Plan a Moment screen for Cocoon app.
///
/// Allows users to plan three types of moments:
/// - **Celebrate**: Special occasions (anniversaries, milestones)
/// - **Connect**: Quality time together (dates, coffee)
/// - **Escape**: Multi-day getaways (vacations, trips)
///
/// Features progressive reveal - each card appears only after the previous
/// one is completed. Uses health card-style dotted progress highlights.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/moment.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/active_card.dart';
import '../../widgets/moment_type_icon.dart';
import '../../widgets/slide_to_action.dart';

/// Plan a Moment screen for creating new moments.
class PlanMomentScreen extends StatefulWidget {
  const PlanMomentScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<PlanMomentScreen> createState() => _PlanMomentScreenState();
}

class _PlanMomentScreenState extends State<PlanMomentScreen> {
  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Form state
  MomentType? _selectedType;
  String? _selectedPreset;
  DateTime? _startDate; // null until user selects
  DateTime? _endDate;
  TimeSlot? _selectedTimeSlot;
  RepeatSchedule _repeatSchedule = RepeatSchedule.never;

  // UI state
  bool _isSubmitting = false;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {}); // Rebuild for validation
    });
    _nameFocusNode.addListener(() {
      setState(() {}); // Rebuild for focus changes
    });
    _notesFocusNode.addListener(() {
      setState(() {}); // Rebuild for focus changes
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  String get _momentName => _nameController.text.trim();

  /// Step 1: Type selected
  bool get _step1Complete => _selectedType != null;
  
  /// Step 2: Name filled
  bool get _step2Complete => _step1Complete && _momentName.isNotEmpty;
  
  /// Step 3: Date filled (must be selected, not default)
  bool get _step3Complete {
    if (!_step2Complete) return false;
    if (_startDate == null) return false;
    if (_selectedType == MomentType.escape) return _endDate != null;
    return true;
  }
  
  /// Step 4: Time filled (only for Connect)
  bool get _step4Complete {
    if (!_step3Complete) return false;
    if (_selectedType == MomentType.connect) return _selectedTimeSlot != null;
    return true;
  }

  bool get _canSubmit => _step4Complete;

  List<String> get _presets {
    return switch (_selectedType) {
      MomentType.celebrate => ['Anniversary', 'Promotion', 'Move in', '...'],
      MomentType.connect => ['Date Night', 'Brunch', 'Movie', 'Walk', 'House Party', 'Shopping', 'Socials', '...'],
      MomentType.escape => ['Festival', 'Retreat', 'Time off', 'Weekend Getaway', 'Beach Trip', '...'],
      null => [],
    };
  }

  
  String get _nameCardHeading {
    return switch (_selectedType) {
      MomentType.celebrate => 'Occasion',
      MomentType.connect => 'Activity',
      MomentType.escape => 'Your Escape',
      null => 'Details',
    };
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _selectType(MomentType type) {
    _dismissKeyboard();
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedType = type;
      _selectedPreset = null;
      _nameController.clear();
      _startDate = null;
      _endDate = null;
      _selectedTimeSlot = null;
      _repeatSchedule = RepeatSchedule.never;
    });
  }

  void _selectPreset(String preset) {
    HapticFeedback.lightImpact();
    if (preset == '...') {
      _nameFocusNode.requestFocus();
      return;
    }
    _nameController.value = TextEditingValue(
      text: preset,
      selection: TextSelection.collapsed(offset: preset.length),
    );
    setState(() => _selectedPreset = preset);
    _nameFocusNode.requestFocus();
  }

  void _selectTimeSlot(TimeSlot slot) {
    _dismissKeyboard();
    setState(() => _selectedTimeSlot = slot);
  }

  void _selectDate(DateTime date) {
    _dismissKeyboard();
    setState(() => _startDate = date);
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

  Future<void> _pickBothDatesWithStart(DateTime existingStart) async {
    _dismissKeyboard();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.lightImpact();
    await _showDateRangePicker(initialStart: existingStart);
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

  /// Shared theme for date pickers
  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.accentRed,
          onPrimary: Colors.white,
          primaryContainer: AppColors.accentRed.withValues(alpha: 0.2),
          surface: AppColors.pureBlack,
          onSurface: AppColors.lightText,
          secondary: AppColors.accentRed,
          onSecondary: Colors.white,
          surfaceContainerHighest: AppColors.darkCardLight,
        ),
        scaffoldBackgroundColor: AppColors.pureBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.pureBlack,
          foregroundColor: AppColors.lightText,
          elevation: 0,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.pureBlack,
          headerBackgroundColor: AppColors.pureBlack,
          headerForegroundColor: AppColors.lightText,
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) return AppColors.warmMuted;
            return AppColors.lightText;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.accentRed;
            return Colors.transparent;
          }),
          todayForegroundColor: WidgetStateProperty.all(AppColors.accentRed),
          todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
          surfaceTintColor: Colors.transparent,
          dividerColor: AppColors.cardVariant,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.darkCardLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accentRed),
            ),
          ),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _submitMoment() async {
    if (!_canSubmit || _isSubmitting) return;

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final notes = _notesController.text.trim();
      final momentId = await _firestoreService.createMoment(
        spaceId: widget.spaceId,
        name: _momentName,
        type: _selectedType!,
        startDate: _startDate!,
        endDate: _selectedType == MomentType.escape ? _endDate : null,
        timeSlot: _selectedType == MomentType.connect ? _selectedTimeSlot : null,
        repeatSchedule: _repeatSchedule,
        notes: notes.isNotEmpty ? notes : null,
        createdBy: userId,
      );

      // Log activity
      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';
      
      await _firestoreService.logMomentPlannedActivity(
        spaceId: widget.spaceId,
        userId: userId,
        userName: userName,
        momentId: momentId,
        momentName: _momentName,
        momentType: _selectedType!.value,
        startDate: _startDate!,
        endDate: _selectedType == MomentType.escape ? _endDate : null,
      );

      HapticFeedback.heavyImpact();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating moment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          HapticFeedback.lightImpact();
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.pureBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Plan a Moment',
            style: AppTypography.appBarTitle(weight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.lightText),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelection(),
              if (_step1Complete) ...[
                const SizedBox(height: 16),
                _buildNameCard(),
              ],
              if (_step2Complete) ...[
                const SizedBox(height: 16),
                _buildDateCard(),
              ],
              if (_step3Complete && _selectedType == MomentType.connect) ...[
                const SizedBox(height: 16),
                _buildTimeCard(),
              ],
              if (_step4Complete) ...[
                const SizedBox(height: 16),
                _buildNotesCard(),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
        bottomNavigationBar: _canSubmit
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SlideToAction(
                    label: 'Slide to save',
                    loadingLabel: 'Saving...',
                    onConfirm: _submitMoment,
                    isLoading: _isSubmitting,
                    enabled: _canSubmit,
                  ),
                ),
              )
            : null,
      ),
    );
  }
  
  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  // ---------------------------------------------------------------------------
  // Type Selection - Health Card Style
  // ---------------------------------------------------------------------------

  String _getTypeHint(MomentType type) {
    return switch (type) {
      MomentType.celebrate => 'your special day',
      MomentType.connect => 'over a date',
      MomentType.escape => 'the everyday',
    };
  }

  Widget _buildTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOMENT TO',
            style: GoogleFonts.inter(
              color: _step1Complete ? AppColors.accentRed : AppColors.warmMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          // Helper text - only show when nothing selected
          if (!_step1Complete) ...[
            const SizedBox(height: 4),
            Text(
              'What kind of moment are you dreaming of?',
              style: GoogleFonts.inter(
                color: AppColors.warmMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 20),
          
          Row(
            children: [
              _buildTypeOption(MomentType.connect, 'Connect'),
              const SizedBox(width: 12),
              _buildTypeOption(MomentType.celebrate, 'Celebrate'),
              const SizedBox(width: 12),
              _buildTypeOption(MomentType.escape, 'Escape'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(MomentType type, String label) {
    final isSelected = _selectedType == type;
    final noneSelected = _selectedType == null;
    
    // Colors: red when none selected, black when selected, dim when another is selected
    final iconColor = isSelected ? AppColors.pureBlack : (noneSelected ? AppColors.accentRed : AppColors.warmMuted);
    final textColor = isSelected ? AppColors.pureBlack : (noneSelected ? AppColors.accentRed : AppColors.warmMuted);
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.accentRed
                : AppColors.cardVariant,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accentRed.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon - red with glow when none selected, black when selected, dim otherwise
              Container(
                decoration: (noneSelected && !isSelected)
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentRed.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      )
                    : null,
                child: getMomentTypeIconWidget(type, size: 24, color: iconColor),
              ),
              const SizedBox(height: 6),
              // Label - red when none selected, black when selected, dim otherwise
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Flowing hint appears when selected - same color as label
              if (isSelected) ...[
                const SizedBox(height: 4),
                Text(
                  _getTypeHint(type),
                  style: GoogleFonts.inter(
                    color: AppColors.pureBlack.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Name / Occasion Card
  // ---------------------------------------------------------------------------

  Widget _buildNameCard() {
    final hasName = _momentName.isNotEmpty;
    final isFocused = _nameFocusNode.hasFocus;
    final isActive = hasName || isFocused;
    // Show presets when no text and not focused
    final showPresets = !hasName && !isFocused;
    
    return GestureDetector(
      onTap: () => _nameFocusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: ActiveCard(
        heading: _nameCardHeading,
        isActive: isActive,
        helperText: showPresets ? _getHelperText() : null,
        hideHelperWhenActive: true,
        shrinkWhenActive: true,
        showBorder: isFocused,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text field - always present, like Reflection
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              style: AppTypography.bodyMedium(color: AppColors.subtleText),
              cursorColor: AppColors.accentRed,
              decoration: InputDecoration(
                hintText: showPresets ? null : 'Type something...',
                hintStyle: AppTypography.bodyMedium(color: AppColors.dimText),
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              maxLines: 1,
              minLines: 1,
            ),
            // Preset suggestions - only when empty and not focused
            if (showPresets) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((preset) => _buildPresetPill(preset)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _getHelperText() => 'Pick one or name your own';

  Widget _buildPresetPill(String preset) {
    final isSelected = _selectedPreset == preset;
    
    return GestureDetector(
      onTap: () => _selectPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accentRed.withValues(alpha: 0.2)
              : AppColors.cardVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          preset,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.accentRed : AppColors.warmMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date Card
  // ---------------------------------------------------------------------------

  Widget _buildDateCard() {
    final isEscape = _selectedType == MomentType.escape;
    
    if (isEscape) {
      return _buildEscapeDatesCard();
    }
    
    // Non-escape: simple single date - tapping anywhere opens picker
    final hasDate = _startDate != null;
    return GestureDetector(
      onTap: _pickStartDate,
      behavior: HitTestBehavior.opaque,
      child: ActiveCard(
        heading: 'Date',
        isActive: hasDate,
        hideHelperWhenActive: true,
        shrinkWhenActive: true,
        child: hasDate ? _buildDateSelected() : _buildDateOptions(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Escape Dates - Two-step flow with nights
  // ---------------------------------------------------------------------------

  Widget _buildEscapeDatesCard() {
    final hasStartDate = _startDate != null;
    final hasEndDate = _endDate != null;
    final isComplete = hasStartDate && hasEndDate;
    
    // Determine helper text based on state
    String? helperText;
    if (!hasStartDate) {
      helperText = 'When are you leaving?';
    } else if (!hasEndDate) {
      helperText = 'How long is the getaway?';
    }
    
    // In nights selection state, tapping anywhere opens two-date picker
    final isInNightsState = hasStartDate && !hasEndDate;
    
    final card = ActiveCard(
      heading: 'Dates',
      isActive: isComplete,
      helperText: helperText,
      hideHelperWhenActive: true,
      shrinkWhenActive: true,
      child: _buildEscapeDatesContent(),
    );
    
    if (isInNightsState) {
      return GestureDetector(
        onTap: () => _pickBothDatesWithStart(_startDate!),
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    
    return card;
  }

  Widget _buildEscapeDatesContent() {
    final hasStartDate = _startDate != null;
    final hasEndDate = _endDate != null;
    
    // State 1: No start date - show start date options
    if (!hasStartDate) {
      return _buildDateOptions();
    }
    
    // State 2: Has start date but no end date - show nights options
    if (!hasEndDate) {
      return _buildNightsOptions();
    }
    
    // State 3: Both dates selected - show summary
    return _buildEscapeSummary();
  }

  Widget _buildNightsOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show selected start date (tappable to open two-date picker)
        GestureDetector(
          onTap: () => _pickBothDatesWithStart(_startDate!),
          child: Row(
            children: [
              Text('From ', style: GoogleFonts.inter(color: AppColors.dimText, fontSize: 13)),
              Text(
                _formatDate(_startDate!),
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Nights options
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildNightPill(1),
            _buildNightPill(2),
            _buildNightPill(3),
            _buildDatePill('Pick date', _pickEndDateOnly),
          ],
        ),
      ],
    );
  }

  Future<void> _pickEndDateOnly() async {
    _dismissKeyboard();
    HapticFeedback.lightImpact();
    await _showDateRangePicker(initialStart: _startDate);
  }

  Widget _buildNightPill(int nights) {
    final label = nights == 1 ? '1 night' : '$nights nights';
    return _buildPill(label, () {
      _dismissKeyboard();
      HapticFeedback.lightImpact();
      setState(() => _endDate = _startDate!.add(Duration(days: nights)));
    });
  }

  Widget _buildEscapeSummary() {
    final nights = _endDate!.difference(_startDate!).inDays;
    final nightsText = nights == 1 ? '1 night' : '$nights nights';
    
    return GestureDetector(
      onTap: _pickBothDates,
      child: Row(
        children: [
          // Dates - matching "Weekend Getaway" style
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTypography.bodyMedium(color: AppColors.subtleText),
                children: [
                  TextSpan(
                    text: 'From ',
                    style: GoogleFonts.inter(color: AppColors.dimText),
                  ),
                  TextSpan(text: _formatDate(_startDate!)),
                  TextSpan(
                    text: ' to ',
                    style: GoogleFonts.inter(color: AppColors.dimText),
                  ),
                  TextSpan(text: _formatDate(_endDate!)),
                ],
              ),
            ),
          ),
          // Nights badge on the right
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date Options (shared for non-escape and escape start date)
  // ---------------------------------------------------------------------------

  Widget _buildDateOptions() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final isEscape = _selectedType == MomentType.escape;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildDatePill('Today', () => _selectDate(today)),
        _buildDatePill('Tomorrow', () => _selectDate(tomorrow)),
        _buildDatePill(
          isEscape ? 'Pick dates' : 'Pick a date', 
          isEscape ? _pickBothDates : _pickStartDate,
        ),
      ],
    );
  }

  Widget _buildDatePill(String label, VoidCallback onTap) => _buildPill(label, onTap);

  Widget _buildDateSelected() {
    return GestureDetector(
      onTap: _pickStartDate,
      child: Text(
        _formatDate(_startDate!),
        style: AppTypography.bodyMedium(color: AppColors.subtleText),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Time Card (Connect only)
  // ---------------------------------------------------------------------------

  Widget _buildTimeCard() {
    final hasTime = _selectedTimeSlot != null;
    
    return ActiveCard(
      heading: 'Time',
      isActive: hasTime,
      helperText: !hasTime ? 'Slide to select time' : null,
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

  // Track drag position for stretchy effect
  double? _dragPosition;
  
  Color _getTimeSlotColor(int index) {
    final progress = index / (TimeSlot.values.length - 1);
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress) ?? AppColors.nightColor;
  }
  
  Color _getTimeSlotColorFromProgress(double progress) {
    return Color.lerp(AppColors.morningColor, AppColors.nightColor, progress.clamp(0.0, 1.0)) ?? AppColors.nightColor;
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
                    // Show first slot as selected when nothing is selected yet
                    final isSelected = _selectedTimeSlot == slot || 
                        (_selectedTimeSlot == null && index == 0);
                    
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

  // ---------------------------------------------------------------------------
  // Notes Card (optional)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Reusable pill button for date/night options
  Widget _buildPill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.warmMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
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
