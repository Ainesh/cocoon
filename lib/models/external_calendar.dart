/// Unified external calendar models (provider-agnostic).
///
/// Shared representation for Google and Apple calendars and events,
/// so the UI doesn't need to know which provider is active.
library;

import 'moment.dart';

/// A calendar from an external provider (Google or Apple).
class ExternalCalendar {
  const ExternalCalendar({
    required this.id,
    required this.name,
    this.color,
    this.isReadOnly = false,
  });

  final String id;
  final String name;
  final int? color;
  final bool isReadOnly;

  @override
  String toString() => 'ExternalCalendar($name, $id)';
}

/// An event from an external calendar.
class ExternalEvent {
  const ExternalEvent({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.calendarId,
    this.calendarName,
    this.isAllDay = false,
    this.description,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final String? calendarId;
  final String? calendarName;
  final bool isAllDay;
  final String? description;

  /// Whether this spans multiple calendar days.
  bool get isMultiDay {
    if (endDate == null) return false;
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return e.isAfter(s);
  }

  /// Converts to a [Moment] for display in the moment details sheet.
  ///
  /// Uses [MomentType.external] with layout hints via endDate/timeSlot:
  /// - Multi-day → has endDate (details sheet shows date range + nights)
  /// - Timed single → has TimeSlot (details sheet shows time card)
  /// - All-day single → no endDate, no timeSlot (details sheet shows date only)
  ///
  /// [providerLabel] is stored in createdBy for the "Synced from..." subtitle.
  Moment toMoment({String providerLabel = 'External Calendar'}) {
    TimeSlot? timeSlot;

    if (!isAllDay && !isMultiDay) {
      final hour = startDate.hour;
      if (hour < 12) {
        timeSlot = TimeSlot.morning;
      } else if (hour < 17) {
        timeSlot = TimeSlot.afternoon;
      } else if (hour < 21) {
        timeSlot = TimeSlot.evening;
      } else {
        timeSlot = TimeSlot.night;
      }
    }

    return Moment(
      id: 'ext_$id',
      name: title,
      type: MomentType.external,
      startDate: startDate,
      endDate: isMultiDay ? endDate : null,
      timeSlot: timeSlot,
      notes: (description != null && description!.isNotEmpty)
          ? description
          : null,
      createdBy: providerLabel,
    );
  }

  @override
  String toString() => 'ExternalEvent($title, $startDate)';
}
