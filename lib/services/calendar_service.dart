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

  /// Signs in with Google and requests calendar scope.
  /// Returns the linked [CalendarIntegration] or null on cancel/failure.
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

  /// Finds or creates a Google Calendar with the given name.
  /// Returns the calendar ID.
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

  /// Creates a Google Calendar event for the given moment.
  /// Uses the space's dedicated calendar if available, falls back to primary.
  Future<String?> syncToGoogle(
    Moment moment,
    String? calendarId,
  ) async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        final reAuth = await _googleSignIn.signIn();
        if (reAuth == null) return null;
      }

      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      final calApi = gcal.CalendarApi(client);

      final event = gcal.Event()
        ..summary = moment.name
        ..description = moment.notes;

      if (moment.endDate != null) {
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

  /// Requests calendar permission and returns available writable calendars.
  Future<List<Calendar>> getDeviceCalendars() async {
    final permResult = await _deviceCalendarPlugin.requestPermissions();
    if (permResult.isSuccess && permResult.data == true) {
      final result = await _deviceCalendarPlugin.retrieveCalendars();
      return (result.data ?? <Calendar>[])
          .where((c) => c.isReadOnly == false)
          .toList();
    }
    return [];
  }

  /// Links to Apple Calendar. Creates a local calendar named after the space
  /// or reuses one if it already exists.
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

      final calendarId = await _getOrCreateAppleCalendar(spaceName);
      if (calendarId == null) return null;

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

  /// Finds or creates a local calendar with the given space name.
  Future<String?> _getOrCreateAppleCalendar(String spaceName) async {
    try {
      final result = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = result.data ?? [];

      final match = calendars.where(
        (c) => c.name?.toLowerCase() == spaceName.toLowerCase(),
      );
      if (match.isNotEmpty && match.first.id != null) {
        return match.first.id;
      }

      final createResult = await _deviceCalendarPlugin.createCalendar(
        spaceName,
        localAccountName: spaceName,
      );
      if (createResult.isSuccess && createResult.data != null) {
        return createResult.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating Apple Calendar: $e');
      return null;
    }
  }

  /// Creates a device calendar event for the given moment.
  Future<String?> syncToApple(Moment moment, String calendarId) async {
    try {
      final startDate = moment.startDate;
      final endDate =
          moment.endDate ?? moment.startDate.add(const Duration(days: 1));

      final event = Event(calendarId)
        ..title = moment.name
        ..description = moment.notes
        ..start = TZDateTime.from(startDate, local)
        ..end = TZDateTime.from(endDate, local)
        ..allDay = true;

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        return result!.data;
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

  /// Returns all calendars from the linked provider as [ExternalCalendar].
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
      final account = await _googleSignIn.signInSilently();
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

  /// Fetches events from the specified calendars for a given month.
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
      final account = await _googleSignIn.signInSilently();
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

  /// Syncs a moment to the user's linked calendar (Google or Apple).
  /// Returns the external event ID on success, null on failure.
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
