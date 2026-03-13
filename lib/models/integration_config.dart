/// Integration configuration models for external service connections.
///
/// Supports per-user integrations stored in `users/{userId}.integrations`.
/// Currently supports Calendar integration (Google or Apple).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported calendar providers.
enum CalendarProvider {
  google('google', 'Google Calendar'),
  apple('apple', 'Apple Calendar');

  const CalendarProvider(this.value, this.label);

  final String value;
  final String label;

  static CalendarProvider fromValue(String value) {
    return CalendarProvider.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CalendarProvider.google,
    );
  }
}

/// Calendar integration state for a single user.
class CalendarIntegration {
  const CalendarIntegration({
    required this.provider,
    required this.enabled,
    this.linkedAt,
    this.email,
    this.calendarId,
  });

  final CalendarProvider provider;
  final bool enabled;
  final DateTime? linkedAt;
  final String? email;
  final String? calendarId;

  factory CalendarIntegration.fromJson(Map<String, dynamic> json) {
    return CalendarIntegration(
      provider: CalendarProvider.fromValue(json['provider'] as String? ?? 'google'),
      enabled: json['enabled'] as bool? ?? false,
      linkedAt: json['linkedAt'] != null
          ? (json['linkedAt'] as Timestamp).toDate()
          : null,
      email: json['email'] as String?,
      calendarId: json['calendarId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.value,
      'enabled': enabled,
      'linkedAt': linkedAt != null ? Timestamp.fromDate(linkedAt!) : null,
      if (email != null) 'email': email,
      if (calendarId != null) 'calendarId': calendarId,
    };
  }

  CalendarIntegration copyWith({
    CalendarProvider? provider,
    bool? enabled,
    DateTime? linkedAt,
    String? email,
    String? calendarId,
  }) {
    return CalendarIntegration(
      provider: provider ?? this.provider,
      enabled: enabled ?? this.enabled,
      linkedAt: linkedAt ?? this.linkedAt,
      email: email ?? this.email,
      calendarId: calendarId ?? this.calendarId,
    );
  }

  @override
  String toString() =>
      'CalendarIntegration(${provider.value}, enabled=$enabled)';
}

/// Top-level integration config for a user.
///
/// Extensible — future integrations (Spotify, Photos, etc.) add fields here.
class IntegrationConfig {
  const IntegrationConfig({this.calendar});

  final CalendarIntegration? calendar;

  bool get hasCalendar => calendar != null && calendar!.enabled;

  factory IntegrationConfig.fromJson(Map<String, dynamic> json) {
    return IntegrationConfig(
      calendar: json['calendar'] != null
          ? CalendarIntegration.fromJson(
              Map<String, dynamic>.from(json['calendar'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (calendar != null) 'calendar': calendar!.toJson(),
    };
  }

  IntegrationConfig copyWith({CalendarIntegration? calendar}) {
    return IntegrationConfig(calendar: calendar ?? this.calendar);
  }

  static const empty = IntegrationConfig();
}
