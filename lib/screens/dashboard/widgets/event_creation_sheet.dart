/// Event creation bottom sheet for creating new couple events.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/space_event.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/theme.dart';

/// Bottom sheet widget for creating new events.
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
  EventType _selectedType = EventType.dateNight;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = widget.authService.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final startTime = DateTime(
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
        scheduledAt: startTime,
        createdBy: userId,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'New Event',
            style: TextStyle(
              color: AppColors.warmLight,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          
          // Event title field
          TextField(
            controller: _titleController,
            style: TextStyle(color: AppColors.warmLight),
            decoration: InputDecoration(
              labelText: 'Event title',
              labelStyle: TextStyle(color: AppColors.warmMuted),
              filled: true,
              fillColor: AppColors.darkCardLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Event type selector
          SegmentedButton<EventType>(
            segments: const [
              ButtonSegment(value: EventType.dateNight, label: Text('Date Night')),
              ButtonSegment(value: EventType.checkIn, label: Text('Check-in')),
              ButtonSegment(value: EventType.special, label: Text('Special')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (v) => setState(() => _selectedType = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accentRed.withValues(alpha: 0.2);
                }
                return AppColors.darkCardLight;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.accentRed;
                return AppColors.warmDim;
              }),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date and time pickers
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('MMM d').format(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (time != null) setState(() => _selectedTime = time);
                  },
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_selectedTime.format(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Create button
          FilledButton(
            onPressed: _isCreating ? null : _createEvent,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: AppColors.pureBlack,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isCreating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pureBlack,
                    ),
                  )
                : const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
