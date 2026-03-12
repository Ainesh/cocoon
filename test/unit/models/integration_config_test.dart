/// Unit tests for IntegrationConfig and CalendarIntegration models.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/integration_config.dart';

void main() {
  group('CalendarProvider', () {
    test('fromValue returns correct provider for known values', () {
      expect(CalendarProvider.fromValue('google'), CalendarProvider.google);
      expect(CalendarProvider.fromValue('apple'), CalendarProvider.apple);
    });

    test('fromValue defaults to google for unknown values', () {
      expect(CalendarProvider.fromValue('unknown'), CalendarProvider.google);
      expect(CalendarProvider.fromValue(''), CalendarProvider.google);
    });

    test('each provider has value and label', () {
      for (final p in CalendarProvider.values) {
        expect(p.value, isNotEmpty);
        expect(p.label, isNotEmpty);
      }
    });
  });

  group('CalendarIntegration', () {
    test('fromJson parses all fields correctly', () {
      final now = DateTime.now();
      final json = {
        'provider': 'google',
        'enabled': true,
        'linkedAt': Timestamp.fromDate(now),
        'email': 'test@gmail.com',
        'calendarId': 'cal_123',
      };

      final integration = CalendarIntegration.fromJson(json);

      expect(integration.provider, CalendarProvider.google);
      expect(integration.enabled, true);
      expect(integration.linkedAt, isNotNull);
      expect(integration.email, 'test@gmail.com');
      expect(integration.calendarId, 'cal_123');
    });

    test('fromJson handles missing/null fields with defaults', () {
      final integration = CalendarIntegration.fromJson({});

      expect(integration.provider, CalendarProvider.google);
      expect(integration.enabled, false);
      expect(integration.linkedAt, isNull);
      expect(integration.email, isNull);
    });

    test('toJson produces correct map', () {
      final integration = CalendarIntegration(
        provider: CalendarProvider.apple,
        enabled: true,
        linkedAt: DateTime(2026, 3, 1),
        calendarId: 'default',
      );

      final json = integration.toJson();

      expect(json['provider'], 'apple');
      expect(json['enabled'], true);
      expect(json['linkedAt'], isA<Timestamp>());
      expect(json['calendarId'], 'default');
      expect(json.containsKey('email'), false);
    });

    test('round-trip: toJson then fromJson preserves data', () {
      final original = CalendarIntegration(
        provider: CalendarProvider.google,
        enabled: true,
        linkedAt: DateTime(2026, 3, 10),
        email: 'user@example.com',
      );

      final restored = CalendarIntegration.fromJson(original.toJson());

      expect(restored.provider, original.provider);
      expect(restored.enabled, original.enabled);
      expect(restored.email, original.email);
    });

    test('copyWith creates correct copy', () {
      final original = CalendarIntegration(
        provider: CalendarProvider.google,
        enabled: true,
        email: 'a@b.com',
      );

      final copy = original.copyWith(enabled: false);

      expect(copy.provider, CalendarProvider.google);
      expect(copy.enabled, false);
      expect(copy.email, 'a@b.com');
    });

    test('toString returns expected format', () {
      final integration = CalendarIntegration(
        provider: CalendarProvider.google,
        enabled: true,
      );
      expect(integration.toString(), contains('google'));
      expect(integration.toString(), contains('true'));
    });
  });

  group('IntegrationConfig', () {
    test('empty has no calendar', () {
      expect(IntegrationConfig.empty.calendar, isNull);
      expect(IntegrationConfig.empty.hasCalendar, false);
    });

    test('hasCalendar returns true when calendar is enabled', () {
      final config = IntegrationConfig(
        calendar: CalendarIntegration(
          provider: CalendarProvider.google,
          enabled: true,
        ),
      );
      expect(config.hasCalendar, true);
    });

    test('hasCalendar returns false when calendar is disabled', () {
      final config = IntegrationConfig(
        calendar: CalendarIntegration(
          provider: CalendarProvider.google,
          enabled: false,
        ),
      );
      expect(config.hasCalendar, false);
    });

    test('fromJson parses nested calendar', () {
      final json = {
        'calendar': {
          'provider': 'apple',
          'enabled': true,
        },
      };

      final config = IntegrationConfig.fromJson(json);

      expect(config.calendar, isNotNull);
      expect(config.calendar!.provider, CalendarProvider.apple);
      expect(config.hasCalendar, true);
    });

    test('fromJson handles missing calendar', () {
      final config = IntegrationConfig.fromJson({});
      expect(config.calendar, isNull);
      expect(config.hasCalendar, false);
    });

    test('toJson produces correct map', () {
      final config = IntegrationConfig(
        calendar: CalendarIntegration(
          provider: CalendarProvider.google,
          enabled: true,
        ),
      );

      final json = config.toJson();

      expect(json.containsKey('calendar'), true);
      expect((json['calendar'] as Map)['provider'], 'google');
    });

    test('toJson omits null calendar', () {
      final json = IntegrationConfig.empty.toJson();
      expect(json.containsKey('calendar'), false);
    });
  });
}
