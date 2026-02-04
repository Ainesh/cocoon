/// Plan a Moment screen for Cocoon app.
///
/// Allows users to plan three types of moments:
/// - **Celebrate**: Special occasions (birthdays, anniversaries)
/// - **Connect**: Quality time together (dates, coffee)
/// - **Escape**: Multi-day getaways (vacations, trips)
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
import '../../widgets/neumorphic_container.dart';
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
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  TimeSlot? _selectedTimeSlot;
  RepeatSchedule _repeatSchedule = RepeatSchedule.never;

  // UI state
  bool _isSubmitting = false;
  final _customNameController = TextEditingController();
  final _customNameFocusNode = FocusNode();
  bool _isCustomNameFocused = false;

  @override
  void initState() {
    super.initState();
    _customNameFocusNode.addListener(() {
      setState(() => _isCustomNameFocused = _customNameFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _customNameFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  /// The name to use for the moment.
  String get _momentName {
    if (_customNameController.text.isNotEmpty) {
      return _customNameController.text;
    }
    return _selectedPreset ?? '';
  }

  /// Whether the form is valid and ready to submit.
  bool get _canSubmit {
    if (_selectedType == null) return false;
    if (_momentName.isEmpty) return false;
    
    if (_selectedType == MomentType.connect && _selectedTimeSlot == null) {
      return false;
    }
    
    if (_selectedType == MomentType.escape && _endDate == null) {
      return false;
    }
    
    return true;
  }

  /// Get presets for the selected type.
  List<String> get _presets {
    return switch (_selectedType) {
      MomentType.celebrate => CelebratePresets.options,
      MomentType.connect => ConnectPresets.options,
      MomentType.escape => EscapePresets.options,
      null => [],
    };
  }

  /// Get repeat options for the selected type.
  List<RepeatSchedule> get _repeatOptions {
    return switch (_selectedType) {
      MomentType.celebrate => [RepeatSchedule.never, RepeatSchedule.yearly],
      MomentType.connect => [
          RepeatSchedule.never,
          RepeatSchedule.daily,
          RepeatSchedule.weekly,
          RepeatSchedule.monthly,
        ],
      MomentType.escape => [RepeatSchedule.never, RepeatSchedule.yearly],
      null => [RepeatSchedule.never],
    };
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _selectType(MomentType type) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedType = type;
      _selectedPreset = null;
      _customNameController.clear();
      _selectedTimeSlot = null;
      _endDate = null;
      _repeatSchedule = RepeatSchedule.never;
    });
  }

  void _selectPreset(String preset) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPreset = preset;
      _customNameController.clear();
    });
  }

  void _onCustomNameChanged(String value) {
    setState(() {
      if (value.isNotEmpty) {
        _selectedPreset = null;
      }
    });
  }

  void _selectTimeSlot(TimeSlot slot) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTimeSlot = slot);
  }

  void _selectRepeat(RepeatSchedule schedule) {
    HapticFeedback.lightImpact();
    setState(() => _repeatSchedule = schedule);
  }

  Future<void> _pickStartDate() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // If end date is before start date, reset it
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 2)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 60)),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _submitMoment() async {
    if (!_canSubmit || _isSubmitting) return;

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.createMoment(
        spaceId: widget.spaceId,
        name: _momentName,
        type: _selectedType!,
        startDate: _startDate,
        endDate: _selectedType == MomentType.escape ? _endDate : null,
        timeSlot: _selectedType == MomentType.connect ? _selectedTimeSlot : null,
        repeatSchedule: _repeatSchedule,
        createdBy: userId,
      );

      HapticFeedback.heavyImpact();

      if (mounted) {
        context.pop();
      }
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      appBar: AppBar(
        backgroundColor: AppColors.pureBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.warmLight),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Plan a Moment',
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to dismiss
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            HapticFeedback.lightImpact();
            context.pop();
          }
        },
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection
              _buildTypeSelection(),
              
              // Show form if type is selected
              if (_selectedType != null) ...[
                const SizedBox(height: 24),
                _buildForm(),
              ],
              
              // Bottom padding for slide button
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selectedType != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SlideToAction(
                  label: 'Slide to plan moment',
                  loadingLabel: 'Creating...',
                  onConfirm: _submitMoment,
                  isLoading: _isSubmitting,
                  enabled: _canSubmit,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of moment?',
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        
        // Type cards
        _buildTypeCard(
          MomentType.celebrate,
          'Birthdays, anniversaries, special occasions',
        ),
        const SizedBox(height: 12),
        _buildTypeCard(
          MomentType.connect,
          'Dates, coffee, quality time together',
        ),
        const SizedBox(height: 12),
        _buildTypeCard(
          MomentType.escape,
          'Vacations, trips, weekend getaways',
        ),
      ],
    );
  }

  Widget _buildTypeCard(MomentType type, String description) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () => _selectType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentRed : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentRed.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Emoji
            Text(
              type.emoji,
              style: TextStyle(
                fontSize: 28,
                color: isSelected ? null : AppColors.warmMuted,
              ),
            ),
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: isSelected ? AppColors.accentRed : AppColors.warmLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.bodySmall(
                      color: AppColors.warmMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Checkmark
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.accentRed,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected type indicator
        Row(
          children: [
            Text(
              _selectedType!.emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedType!.label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: AppColors.accentRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Presets & custom name
        _buildNameSection(),
        const SizedBox(height: 20),
        
        // Date section
        _buildDateSection(),
        const SizedBox(height: 20),
        
        // Time slot (only for Connect)
        if (_selectedType == MomentType.connect) ...[
          _buildTimeSlotSection(),
          const SizedBox(height: 20),
        ],
        
        // Repeat section
        _buildRepeatSection(),
      ],
    );
  }

  Widget _buildNameSection() {
    final headerText = switch (_selectedType) {
      MomentType.celebrate => "What's the occasion?",
      MomentType.connect => "What are you planning?",
      MomentType.escape => "Where to?",
      null => "",
    };

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.edit_outlined,
            title: headerText,
          ),
          const SizedBox(height: 12),
          
          // Preset chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presets.take(6).map((preset) => _buildPresetChip(preset)),
              _buildCustomChip(),
            ],
          ),
          
          // Custom name input (if custom selected)
          if (_selectedPreset == null && 
              (_customNameController.text.isNotEmpty || _isCustomNameFocused)) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customNameController,
              focusNode: _customNameFocusNode,
              onChanged: _onCustomNameChanged,
              style: AppTypography.bodyMedium(color: AppColors.warmLight),
              decoration: InputDecoration(
                hintText: 'Type custom name...',
                hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
                filled: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.cardVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentRed),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String preset) {
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
          border: Border.all(
            color: isSelected ? AppColors.accentRed : Colors.transparent,
            width: 1,
          ),
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

  Widget _buildCustomChip() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPreset = null;
        });
        _customNameFocusNode.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isCustomNameFocused ? AppColors.accentRed : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: _isCustomNameFocused ? AppColors.accentRed : AppColors.warmMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Custom',
              style: GoogleFonts.inter(
                color: _isCustomNameFocused ? AppColors.accentRed : AppColors.warmMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.calendar_today_outlined,
            title: _selectedType == MomentType.escape ? 'DATES' : 'DATE',
          ),
          const SizedBox(height: 12),
          
          if (_selectedType == MomentType.escape) ...[
            // Start and end date for Escape
            Row(
              children: [
                Expanded(child: _buildDateButton(_startDate, 'Start', _pickStartDate)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: AppColors.warmMuted, size: 20),
                ),
                Expanded(child: _buildDateButton(_endDate, 'End', _pickEndDate)),
              ],
            ),
            if (_endDate != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${_endDate!.difference(_startDate).inDays} nights',
                  style: AppTypography.bodySmall(color: AppColors.warmMuted),
                ),
              ),
            ],
          ] else ...[
            // Single date for Celebrate/Connect
            _buildDateButton(_startDate, null, _pickStartDate),
          ],
        ],
      ),
    );
  }

  Widget _buildDateButton(DateTime? date, String? label, VoidCallback onTap) {
    final hasDate = date != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate ? AppColors.accentRed.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: hasDate ? AppColors.accentRed : AppColors.warmMuted,
            ),
            const SizedBox(width: 8),
            Text(
              hasDate ? _formatDate(date) : (label ?? 'Select date'),
              style: GoogleFonts.inter(
                color: hasDate ? AppColors.warmLight : AppColors.warmMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotSection() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.access_time_outlined,
            title: 'TIME',
          ),
          const SizedBox(height: 12),
          
          Row(
            children: TimeSlot.values.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectTimeSlot(slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                      right: slot != TimeSlot.night ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentRed.withValues(alpha: 0.15)
                          : AppColors.cardVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.accentRed : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          slot.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slot.label.substring(0, 4),
                          style: GoogleFonts.inter(
                            color: isSelected ? AppColors.accentRed : AppColors.warmMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatSection() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.repeat,
            title: 'REPEAT',
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _repeatOptions.map((schedule) {
              final isSelected = _repeatSchedule == schedule;
              return GestureDetector(
                onTap: () => _selectRepeat(schedule),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentRed.withValues(alpha: 0.2)
                        : AppColors.cardVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.accentRed : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    schedule.label,
                    style: GoogleFonts.inter(
                      color: isSelected ? AppColors.accentRed : AppColors.warmMuted,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
