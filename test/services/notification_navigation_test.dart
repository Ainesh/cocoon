import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/services/notification_service.dart';

void main() {
  group('NotificationNavigation', () {
    test('isMoment returns true for moment activity types', () {
      const nav = NotificationNavigation(
        type: 'moment_planned',
        spaceId: 'space123',
      );
      expect(nav.isMoment, true);
      expect(nav.isCheckIn, false);
    });

    test('isMoment returns true for all moment variants', () {
      for (final type in [
        'moment_planned',
        'moment_edited',
        'moment_deleted',
        'moment_completed',
      ]) {
        final nav = NotificationNavigation(type: type, spaceId: 'space123');
        expect(nav.isMoment, true, reason: '$type should be a moment type');
      }
    });

    test('isCheckIn returns true for checkin type', () {
      const nav = NotificationNavigation(type: 'checkin', spaceId: 'space123');
      expect(nav.isCheckIn, true);
      expect(nav.isMoment, false);
    });

    test('isMoment and isCheckIn return false for space events', () {
      const nav = NotificationNavigation(
        type: 'space_joined',
        spaceId: 'space123',
      );
      expect(nav.isMoment, false);
      expect(nav.isCheckIn, false);
    });

    test('default entityType and entityId are empty', () {
      const nav = NotificationNavigation(type: 'checkin', spaceId: 'space123');
      expect(nav.entityType, '');
      expect(nav.entityId, '');
    });

    test('toString includes all fields', () {
      const nav = NotificationNavigation(
        type: 'moment_planned',
        spaceId: 'space123',
        entityType: 'moment',
        entityId: 'moment456',
      );
      final str = nav.toString();
      expect(str, contains('moment_planned'));
      expect(str, contains('space123'));
      expect(str, contains('moment'));
      expect(str, contains('moment456'));
    });
  });
}
