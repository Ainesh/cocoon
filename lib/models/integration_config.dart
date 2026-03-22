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

/// Google Drive storage integration state.
class DriveStorageIntegration {
  const DriveStorageIntegration({
    required this.enabled,
    this.linkedAt,
  });

  final bool enabled;
  final DateTime? linkedAt;

  factory DriveStorageIntegration.fromJson(Map<String, dynamic> json) {
    return DriveStorageIntegration(
      enabled: json['enabled'] as bool? ?? false,
      linkedAt: json['linkedAt'] != null
          ? (json['linkedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'linkedAt': linkedAt != null ? Timestamp.fromDate(linkedAt!) : null,
    };
  }
}

/// Top-level integration config for a user.
///
/// Extensible — future integrations (Spotify, Photos, etc.) add fields here.
class IntegrationConfig {
  const IntegrationConfig({this.calendar, this.driveStorage});

  final CalendarIntegration? calendar;
  final DriveStorageIntegration? driveStorage;

  bool get hasCalendar => calendar != null && calendar!.enabled;
  bool get hasDriveStorage => driveStorage != null && driveStorage!.enabled;

  factory IntegrationConfig.fromJson(Map<String, dynamic> json) {
    return IntegrationConfig(
      calendar: json['calendar'] != null
          ? CalendarIntegration.fromJson(
              Map<String, dynamic>.from(json['calendar'] as Map))
          : null,
      driveStorage: json['driveStorage'] != null
          ? DriveStorageIntegration.fromJson(
              Map<String, dynamic>.from(json['driveStorage'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (calendar != null) 'calendar': calendar!.toJson(),
      if (driveStorage != null) 'driveStorage': driveStorage!.toJson(),
    };
  }

  IntegrationConfig copyWith({
    CalendarIntegration? calendar,
    DriveStorageIntegration? driveStorage,
  }) {
    return IntegrationConfig(
      calendar: calendar ?? this.calendar,
      driveStorage: driveStorage ?? this.driveStorage,
    );
  }

  static const empty = IntegrationConfig();
}
