/// Calendar integration service for syncing moments to external calendars.
///
/// Supports Google Calendar (via googleapis). Apple Calendar support
/// uses URL scheme to open events in the native Calendar app.
/// Per-user: each partner links their own calendar independently.
/// Push-only: moments are synced out as events; no pull.
library;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  // Apple Calendar (URL scheme — no native plugin needed)
  // ---------------------------------------------------------------------------

  /// Links Apple Calendar. No OAuth needed — just saves the config.
  Future<CalendarIntegration?> linkApple({
    required String userId,
    required String spaceName,
  }) async {
    try {
      final integration = CalendarIntegration(
        provider: CalendarProvider.apple,
        enabled: true,
        linkedAt: DateTime.now(),
      );
      await _firestore.saveCalendarIntegration(userId, integration);
      return integration;
    } catch (e) {
      debugPrint('Apple Calendar link error: $e');
      return null;
    }
  }

  /// Syncs a moment to Apple Calendar by opening an .ics URL.
  /// Returns a placeholder ID on success (URL launch doesn't return an event ID).
  Future<String?> syncToApple(Moment moment) async {
    try {
      final start = moment.startDate;
      final end = moment.endDate ?? start.add(const Duration(days: 1));

      final startStr = _toIcsDate(start);
      final endStr = _toIcsDate(end);
      final title = Uri.encodeComponent(moment.name);
      final notes = Uri.encodeComponent(moment.notes ?? '');

      final url = Uri.parse(
        'calshow://?title=$title&startDate=$startStr&endDate=$endStr&notes=$notes',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return 'apple_${DateTime.now().millisecondsSinceEpoch}';
      }
      return null;
    } catch (e) {
      debugPrint('Apple Calendar sync error: $e');
      return null;
    }
  }

  static String _toIcsDate(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  // ---------------------------------------------------------------------------
  // List calendars (unified)
  // ---------------------------------------------------------------------------

  Future<List<ExternalCalendar>> listCalendars(
    CalendarIntegration integration,
  ) async {
    if (integration.provider == CalendarProvider.google) {
      return _listGoogleCalendars();
    }
    // Apple Calendar via URL scheme doesn't support listing calendars
    return [];
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
    }
    // Apple Calendar via URL scheme doesn't support fetching events
    return [];
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
      eventId = await syncToApple(moment);
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
