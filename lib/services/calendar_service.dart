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

import '../models/integration_config.dart';
import '../models/moment.dart';
import 'firestore_service.dart';

/// Wraps Google Calendar and Apple Calendar linking + event creation.
class CalendarService {
  CalendarService({FirestoreService? firestoreService})
      : _firestore = firestoreService ?? FirestoreService();

  final FirestoreService _firestore;

  static final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar.events'],
  );

  final _deviceCalendarPlugin = DeviceCalendarPlugin();

  // ---------------------------------------------------------------------------
  // Google Calendar
  // ---------------------------------------------------------------------------

  /// Signs in with Google and requests calendar scope.
  /// Returns the linked [CalendarIntegration] or null on cancel/failure.
  Future<CalendarIntegration?> linkGoogle({required String userId}) async {
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final integration = CalendarIntegration(
        provider: CalendarProvider.google,
        enabled: true,
        linkedAt: DateTime.now(),
        email: account.email,
      );

      await _firestore.saveCalendarIntegration(userId, integration);
      return integration;
    } catch (e) {
      debugPrint('Google Calendar link error: $e');
      return null;
    }
  }

  /// Creates a Google Calendar event for the given moment.
  /// Returns the external event ID on success.
  Future<String?> syncToGoogle(Moment moment) async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        debugPrint('Google sign-in expired, re-authenticating');
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

      final created = await calApi.events.insert(event, 'primary');
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

  /// Requests calendar permission and returns available calendars.
  Future<List<Calendar>> getDeviceCalendars() async {
    final permResult = await _deviceCalendarPlugin.requestPermissions();
    if (permResult.isSuccess && permResult.data == true) {
      final result = await _deviceCalendarPlugin.retrieveCalendars();
      return result.data ?? [];
    }
    return [];
  }

  /// Links to an Apple device calendar.
  Future<CalendarIntegration?> linkApple({
    required String userId,
    required String calendarId,
    String? calendarName,
  }) async {
    try {
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

  /// Creates a device calendar event for the given moment.
  Future<String?> syncToApple(Moment moment, String calendarId) async {
    try {
      final event = Event(calendarId)
        ..title = moment.name
        ..description = moment.notes
        ..start = TZDateTime.from(moment.startDate, local)
        ..end = TZDateTime.from(
          moment.endDate ?? moment.startDate.add(const Duration(hours: 1)),
          local,
        )
        ..allDay = true;

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true) {
        return result!.data;
      }
      return null;
    } catch (e) {
      debugPrint('Apple Calendar sync error: $e');
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
  }) async {
    String? eventId;

    if (integration.provider == CalendarProvider.google) {
      eventId = await syncToGoogle(moment);
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

  void close() => _inner.close();
}
