/// Unified external calendar models (provider-agnostic).
///
/// Shared representation for Google and Apple calendars and events,
/// so the UI doesn't need to know which provider is active.
library;

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

  @override
  String toString() => 'ExternalEvent($title, $startDate)';
}
