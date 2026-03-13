/// Calendar integration service for syncing moments to external calendars.
///
/// Supports Google Calendar (via googleapis) and Apple Calendar (via device_calendar).
/// Per-user: each partner links their own calendar independently.
/// Push-only: moments are synced out as events; no pull.
library;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import '../models/external_calendar.dart';
import '../models/integration_config.dart';
import '../models/moment.dart';
import 'firestore_service.dart';

/// Wraps Google Calendar and Apple Calendar linking + event creation.
class CalendarService {
  CalendarService({FirestoreService? firestoreService})
      : _firestore = firestoreService ?? FirestoreService();

  final FirestoreService _firestore;

  static final _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  final _deviceCalendarPlugin = DeviceCalendarPlugin();

  // ---------------------------------------------------------------------------
  // Google Calendar
  // ---------------------------------------------------------------------------

  Future<CalendarIntegration?> linkGoogle({
    required String userId,
    required String spaceName,
  }) async {
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final calendarId = await _getOrCreateGoogleCalendar(spaceName);

      final integration = CalendarIntegration(
        provider: CalendarProvider.google,
        enabled: true,
        linkedAt: DateTime.now(),
        email: account.email,
        calendarId: calendarId,
      );

      await _firestore.saveCalendarIntegration(userId, integration);
      return integration;
    } catch (e) {
      debugPrint('Google Calendar link error: $e');
      return null;
    }
  }

  Future<String?> _getOrCreateGoogleCalendar(String spaceName) async {
    try {
      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      final calApi = gcal.CalendarApi(client);

      final existing = await calApi.calendarList.list();
      final match = existing.items?.where(
        (c) => c.summary?.toLowerCase() == spaceName.toLowerCase(),
      );
      if (match != null && match.isNotEmpty) {
        client.close();
        return match.first.id;
      }

      final newCal = gcal.Calendar()
        ..summary = spaceName
        ..description = 'Moments from $spaceName';

      final created = await calApi.calendars.insert(newCal);
      client.close();
      return created.id;
    } catch (e) {
      debugPrint('Error creating Google Calendar: $e');
      return null;
    }
  }

  Future<String?> syncToGoogle(Moment moment, String? calendarId) async {
    try {
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return null;

      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      final calApi = gcal.CalendarApi(client);

      final event = gcal.Event()
        ..summary = moment.name
        ..description = moment.notes;

      _applyEventTimes(event, moment);

      final targetCalendar = calendarId ?? 'primary';
      final created = await calApi.events.insert(event, targetCalendar);
      client.close();
      return created.id;
    } catch (e) {
      debugPrint('Google Calendar sync error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Apple Calendar (device_calendar)
  // ---------------------------------------------------------------------------

  Future<CalendarIntegration?> linkApple({
    required String userId,
    required String spaceName,
  }) async {
    try {
      final permResult = await _deviceCalendarPlugin.requestPermissions();
      if (!permResult.isSuccess || permResult.data != true) {
        debugPrint('Apple Calendar permission denied');
        return null;
      }

      // Find the default writable calendar
      final calendarId = await _findDefaultAppleCalendar();
      if (calendarId == null) {
        debugPrint('No writable Apple calendar found');
        return null;
      }

      final integration = CalendarIntegration(
        provider: CalendarProvider.apple,
        enabled: true,
        linkedAt: DateTime.now(),
        calendarId: calendarId,
      );

      await _firestore.saveCalendarIntegration(userId, integration);
      return integration;
    } catch (e) {
      debugPrint('Apple Calendar link error: $e');
      return null;
    }
  }

  /// Finds the first writable calendar on the device, preferring iCloud.
  Future<String?> _findDefaultAppleCalendar() async {
    try {
      final result = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = (result.data ?? <Calendar>[])
          .where((c) => c.isReadOnly == false && c.id != null)
          .toList();

      if (calendars.isEmpty) return null;

      // Prefer iCloud calendar if available
      final icloud = calendars.where(
        (c) => c.accountName?.toLowerCase().contains('icloud') == true,
      );
      if (icloud.isNotEmpty) return icloud.first.id;

      return calendars.first.id;
    } catch (e) {
      debugPrint('Error finding Apple calendar: $e');
      return null;
    }
  }

  Future<String?> syncToApple(Moment moment, String calendarId) async {
    try {
      final permResult = await _deviceCalendarPlugin.requestPermissions();
      if (!permResult.isSuccess || permResult.data != true) {
        debugPrint('Apple Calendar permission denied during sync');
        return null;
      }

      final startDate = moment.startDate;
      final endDate =
          moment.endDate ?? moment.startDate.add(const Duration(days: 1));

      final Event event;
      if (moment.timeSlot != null) {
        final (startHour, endHour) = _timeSlotHours(moment.timeSlot!);
        event = Event(calendarId)
          ..title = moment.name
          ..description = moment.notes ?? ''
          ..start = TZDateTime(local, startDate.year, startDate.month, startDate.day, startHour)
          ..end = TZDateTime(local, startDate.year, startDate.month, startDate.day, endHour);
      } else {
        event = Event(calendarId)
          ..title = moment.name
          ..description = moment.notes ?? ''
          ..start = TZDateTime(local, startDate.year, startDate.month, startDate.day)
          ..end = TZDateTime(local, endDate.year, endDate.month, endDate.day, 23, 59)
          ..allDay = true;
      }

      debugPrint('Apple sync: calendarId=$calendarId, title=${moment.name}');
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      debugPrint('Apple sync result: success=${result?.isSuccess}, data=${result?.data}, errors=${result?.errors}');

      if (result?.isSuccess == true && result?.data != null) {
        return result!.data;
      }

      // If the stored calendar failed, try the default writable calendar
      final fallbackId = await _findDefaultAppleCalendar();
      if (fallbackId != null && fallbackId != calendarId) {
        debugPrint('Apple sync: retrying with fallback calendar $fallbackId');
        final fallbackEvent = Event(fallbackId)
          ..title = moment.name
          ..description = moment.notes ?? ''
          ..start = TZDateTime(local, startDate.year, startDate.month, startDate.day)
          ..end = TZDateTime(local, endDate.year, endDate.month, endDate.day, 23, 59)
          ..allDay = true;

        final fallbackResult =
            await _deviceCalendarPlugin.createOrUpdateEvent(fallbackEvent);
        if (fallbackResult?.isSuccess == true && fallbackResult?.data != null) {
          return fallbackResult!.data;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Apple Calendar sync error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // List calendars (unified)
  // ---------------------------------------------------------------------------

  Future<List<ExternalCalendar>> listCalendars(
    CalendarIntegration integration,
  ) async {
    if (integration.provider == CalendarProvider.google) {
      return _listGoogleCalendars();
    } else {
      return _listAppleCalendars();
    }
  }

  Future<List<ExternalCalendar>> _listGoogleCalendars() async {
    try {
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return [];

      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      final calApi = gcal.CalendarApi(client);

      final list = await calApi.calendarList.list();
      client.close();

      return (list.items ?? []).map((c) {
        return ExternalCalendar(
          id: c.id ?? '',
          name: c.summary ?? c.id ?? '',
          color: c.backgroundColor != null
              ? _parseHexColor(c.backgroundColor!)
              : null,
          isReadOnly: c.accessRole == 'reader',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error listing Google calendars: $e');
      return [];
    }
  }

  Future<List<ExternalCalendar>> _listAppleCalendars() async {
    try {
      final permResult = await _deviceCalendarPlugin.requestPermissions();
      if (!permResult.isSuccess || permResult.data != true) return [];

      final result = await _deviceCalendarPlugin.retrieveCalendars();
      return (result.data ?? <Calendar>[]).map((c) {
        return ExternalCalendar(
          id: c.id ?? '',
          name: c.name ?? '',
          color: c.color,
          isReadOnly: c.isReadOnly ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error listing Apple calendars: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch events (unified)
  // ---------------------------------------------------------------------------

  Future<List<ExternalEvent>> fetchEvents({
    required CalendarIntegration integration,
    required List<String> calendarIds,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    if (integration.provider == CalendarProvider.google) {
      return _fetchGoogleEvents(calendarIds, start, end);
    } else {
      return _fetchAppleEvents(calendarIds, start, end);
    }
  }

  Future<List<ExternalEvent>> _fetchGoogleEvents(
    List<String> calendarIds,
    DateTime start,
    DateTime end,
  ) async {
    try {
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return [];

      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      final calApi = gcal.CalendarApi(client);

      final events = <ExternalEvent>[];
      for (final calId in calendarIds) {
        final result = await calApi.events.list(
          calId,
          timeMin: start.toUtc(),
          timeMax: end.toUtc(),
          singleEvents: true,
          orderBy: 'startTime',
        );
        final calName =
            (await calApi.calendarList.get(calId)).summary ?? calId;
        for (final e in result.items ?? <gcal.Event>[]) {
          final eStart = e.start?.dateTime ?? e.start?.date;
          if (eStart == null) continue;
          events.add(ExternalEvent(
            id: e.id ?? '',
            title: e.summary ?? '(No title)',
            startDate: eStart,
            endDate: e.end?.dateTime ?? e.end?.date,
            calendarId: calId,
            calendarName: calName,
            isAllDay: e.start?.date != null && e.start?.dateTime == null,
            description: e.description,
          ));
        }
      }

      client.close();
      return events;
    } catch (e) {
      debugPrint('Error fetching Google events: $e');
      return [];
    }
  }

  Future<List<ExternalEvent>> _fetchAppleEvents(
    List<String> calendarIds,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final events = <ExternalEvent>[];
      for (final calId in calendarIds) {
        final result = await _deviceCalendarPlugin.retrieveEvents(
          calId,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        for (final e in result.data ?? <Event>[]) {
          events.add(ExternalEvent(
            id: e.eventId ?? '',
            title: e.title ?? '(No title)',
            startDate: e.start?.toLocal() ?? start,
            endDate: e.end?.toLocal(),
            calendarId: calId,
            isAllDay: e.allDay ?? false,
            description: e.description,
          ));
        }
      }
      return events;
    } catch (e) {
      debugPrint('Error fetching Apple events: $e');
      return [];
    }
  }

  /// Sets start/end on a Google Calendar event from a Moment.
  /// Timed events (Connect with TimeSlot) use UTC dateTime.
  /// All-day events use date-only fields.
  static void _applyEventTimes(gcal.Event event, Moment moment) {
    if (moment.timeSlot != null) {
      final (startHour, endHour) = _timeSlotHours(moment.timeSlot!);
      // Construct local time then convert to UTC for the API
      final localStart = DateTime(
        moment.startDate.year,
        moment.startDate.month,
        moment.startDate.day,
        startHour,
      );
      final localEnd = DateTime(
        moment.startDate.year,
        moment.startDate.month,
        moment.startDate.day,
        endHour,
      );
      event.start = gcal.EventDateTime(dateTime: localStart.toUtc());
      event.end = gcal.EventDateTime(dateTime: localEnd.toUtc());
    } else if (moment.endDate != null) {
      event.start = gcal.EventDateTime(date: moment.startDate);
      event.end = gcal.EventDateTime(
        date: moment.endDate!.add(const Duration(days: 1)),
      );
    } else {
      event.start = gcal.EventDateTime(date: moment.startDate);
      event.end = gcal.EventDateTime(
        date: moment.startDate.add(const Duration(days: 1)),
      );
    }
  }

  /// Maps a TimeSlot to (startHour, endHour) for timed calendar events.
  static (int, int) _timeSlotHours(TimeSlot slot) {
    return switch (slot) {
      TimeSlot.morning => (6, 12),
      TimeSlot.afternoon => (12, 17),
      TimeSlot.evening => (17, 21),
      TimeSlot.night => (21, 23),
    };
  }

  static int? _parseHexColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return int.parse('FF$cleaned', radix: 16);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Unified sync
  // ---------------------------------------------------------------------------

  Future<String?> syncMoment({
    required Moment moment,
    required CalendarIntegration integration,
    required String spaceId,
    required String userId,
  }) async {
    String? eventId;

    if (integration.provider == CalendarProvider.google) {
      eventId = await syncToGoogle(moment, integration.calendarId);
    } else if (integration.provider == CalendarProvider.apple) {
      final calId = integration.calendarId;
      if (calId != null) {
        eventId = await syncToApple(moment, calId);
      }
    }

    if (eventId != null) {
      await _firestore.updateMomentExternalEventId(
        spaceId: spaceId,
        momentId: moment.id,
        userId: userId,
        eventId: eventId,
      );
    }

    return eventId;
  }

  // ---------------------------------------------------------------------------
  // Update synced event
  // ---------------------------------------------------------------------------

  /// Updates an already-synced calendar event when a moment is edited.
  /// Looks up the user's event ID from the moment and updates it in-place.
  Future<void> updateCalendarEvent({
    required Moment moment,
    required CalendarIntegration integration,
    required String userId,
  }) async {
    final eventId = moment.externalEventIds?[userId];
    if (eventId == null) return;

    try {
      if (integration.provider == CalendarProvider.google) {
        await _updateGoogleEvent(moment, integration.calendarId, eventId);
      } else if (integration.provider == CalendarProvider.apple) {
        final calId = integration.calendarId;
        if (calId != null) {
          await _updateAppleEvent(moment, calId, eventId);
        }
      }
    } catch (e) {
      debugPrint('Error updating calendar event: $e');
    }
  }

  Future<void> _updateGoogleEvent(
    Moment moment,
    String? calendarId,
    String eventId,
  ) async {
    var account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return;

    final authHeaders = await _googleSignIn.currentUser!.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final calApi = gcal.CalendarApi(client);

    final event = gcal.Event()
      ..summary = moment.name
      ..description = moment.notes;

    _applyEventTimes(event, moment);

    final target = calendarId ?? 'primary';
    await calApi.events.update(event, target, eventId);
    client.close();
  }

  Future<void> _updateAppleEvent(
    Moment moment,
    String calendarId,
    String eventId,
  ) async {
    final startDate = moment.startDate;
    final endDate = moment.endDate ?? startDate.add(const Duration(days: 1));

    final Event event;
    if (moment.timeSlot != null) {
      final (startHour, endHour) = _timeSlotHours(moment.timeSlot!);
      event = Event(calendarId, eventId: eventId)
        ..title = moment.name
        ..description = moment.notes ?? ''
        ..start = TZDateTime(local, startDate.year, startDate.month, startDate.day, startHour)
        ..end = TZDateTime(local, startDate.year, startDate.month, startDate.day, endHour);
    } else {
      event = Event(calendarId, eventId: eventId)
        ..title = moment.name
        ..description = moment.notes ?? ''
        ..start = TZDateTime(local, startDate.year, startDate.month, startDate.day)
        ..end = TZDateTime(local, endDate.year, endDate.month, endDate.day, 23, 59)
        ..allDay = true;
    }

    await _deviceCalendarPlugin.createOrUpdateEvent(event);
  }

  // ---------------------------------------------------------------------------
  // Delete synced event
  // ---------------------------------------------------------------------------

  /// Deletes calendar events for all users who synced this moment.
  Future<void> deleteCalendarEvents({
    required Moment moment,
    required CalendarIntegration integration,
  }) async {
    final eventIds = moment.externalEventIds;
    if (eventIds == null || eventIds.isEmpty) return;

    try {
      if (integration.provider == CalendarProvider.google) {
        for (final eventId in eventIds.values) {
          await _deleteGoogleEvent(integration.calendarId, eventId);
        }
      } else if (integration.provider == CalendarProvider.apple) {
        final calId = integration.calendarId;
        if (calId != null) {
          for (final eventId in eventIds.values) {
            await _deleteAppleEvent(calId, eventId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting calendar events: $e');
    }
  }

  Future<void> _deleteGoogleEvent(String? calendarId, String eventId) async {
    var account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return;

    final authHeaders = await _googleSignIn.currentUser!.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final calApi = gcal.CalendarApi(client);
    final target = calendarId ?? 'primary';
    await calApi.events.delete(target, eventId);
    client.close();
  }

  Future<void> _deleteAppleEvent(String calendarId, String eventId) async {
    await _deviceCalendarPlugin.deleteEvent(calendarId, eventId);
  }

  // ---------------------------------------------------------------------------
  // Unlink
  // ---------------------------------------------------------------------------

  Future<void> unlink(String userId) async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _firestore.removeCalendarIntegration(userId);
  }
}

/// Minimal HTTP client that injects Google auth headers.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
