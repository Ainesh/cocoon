import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/notification_preferences.dart';
import 'package:couple_space/models/activity.dart';

void main() {
  group('NotificationPriority', () {
    test('fromValue returns correct priority', () {
      expect(
        NotificationPriority.fromValue('silent'),
        NotificationPriority.silent,
      );
      expect(NotificationPriority.fromValue('low'), NotificationPriority.low);
      expect(
        NotificationPriority.fromValue('normal'),
        NotificationPriority.normal,
      );
      expect(NotificationPriority.fromValue('high'), NotificationPriority.high);
      expect(
        NotificationPriority.fromValue('critical'),
        NotificationPriority.critical,
      );
    });

    test('fromValue defaults to normal for unknown values', () {
      expect(
        NotificationPriority.fromValue('unknown'),
        NotificationPriority.normal,
      );
      expect(NotificationPriority.fromValue(''), NotificationPriority.normal);
    });

    test('displayName returns human-readable string', () {
      expect(NotificationPriority.silent.displayName, 'Silent');
      expect(NotificationPriority.high.displayName, 'High');
    });
  });

  group('ActivityNotificationConfig', () {
    test('toJson serializes correctly', () {
      const config = ActivityNotificationConfig(
        activityType: ActivityType.checkin,
        enabled: true,
        priority: NotificationPriority.high,
      );
      expect(config.toJson(), {'enabled': true, 'priority': 'high'});
    });

    test('fromJson deserializes correctly', () {
      final config = ActivityNotificationConfig.fromJson(ActivityType.checkin, {
        'enabled': false,
        'priority': 'low',
      });
      expect(config.activityType, ActivityType.checkin);
      expect(config.enabled, false);
      expect(config.priority, NotificationPriority.low);
    });

    test('fromJson uses defaults for missing fields', () {
      final config = ActivityNotificationConfig.fromJson(
        ActivityType.momentPlanned,
        {},
      );
      expect(config.enabled, true);
      expect(config.priority, NotificationPriority.normal);
    });

    test('copyWith updates fields correctly', () {
      const config = ActivityNotificationConfig(
        activityType: ActivityType.checkin,
        enabled: true,
        priority: NotificationPriority.normal,
      );
      final updated = config.copyWith(
        enabled: false,
        priority: NotificationPriority.silent,
      );
      expect(updated.enabled, false);
      expect(updated.priority, NotificationPriority.silent);
      expect(updated.activityType, ActivityType.checkin);
    });
  });

  group('NotificationPreferences', () {
    test('default preferences have expected values', () {
      final prefs = NotificationPreferences();
      expect(prefs.globalEnabled, true);
      expect(prefs.activityConfigs.length, ActivityType.values.length);
    });

    test('shouldNotify returns false when global is disabled', () {
      final prefs = NotificationPreferences(globalEnabled: false);
      expect(prefs.shouldNotify(ActivityType.checkin), false);
      expect(prefs.shouldNotify(ActivityType.spaceJoined), false);
    });

    test('shouldNotify returns false for disabled activity types', () {
      final prefs = NotificationPreferences();
      // space_created is disabled by default
      expect(prefs.shouldNotify(ActivityType.spaceCreated), false);
      // checkin is enabled by default
      expect(prefs.shouldNotify(ActivityType.checkin), true);
    });

    test('getPriority returns correct default priorities', () {
      final prefs = NotificationPreferences();
      expect(
        prefs.getPriority(ActivityType.checkin),
        NotificationPriority.normal,
      );
      expect(
        prefs.getPriority(ActivityType.spaceJoined),
        NotificationPriority.high,
      );
      expect(
        prefs.getPriority(ActivityType.momentEdited),
        NotificationPriority.low,
      );
      expect(
        prefs.getPriority(ActivityType.spaceCreated),
        NotificationPriority.silent,
      );
    });

    test('enabledActivityTypes excludes disabled types', () {
      final prefs = NotificationPreferences();
      final enabled = prefs.enabledActivityTypes;
      expect(enabled.contains(ActivityType.checkin), true);
      expect(enabled.contains(ActivityType.spaceCreated), false);
      expect(enabled.contains(ActivityType.inviteSent), false);
    });

    test('enabledActivityTypes returns empty when global disabled', () {
      final prefs = NotificationPreferences(globalEnabled: false);
      expect(prefs.enabledActivityTypes, isEmpty);
    });

    test('toggleGlobal flips globalEnabled', () {
      final prefs = NotificationPreferences(globalEnabled: true);
      final toggled = prefs.toggleGlobal();
      expect(toggled.globalEnabled, false);
      expect(toggled.toggleGlobal().globalEnabled, true);
    });

    test('toggleActivityType flips enabled for specific type', () {
      final prefs = NotificationPreferences();
      expect(prefs.shouldNotify(ActivityType.checkin), true);
      final toggled = prefs.toggleActivityType(ActivityType.checkin);
      expect(toggled.shouldNotify(ActivityType.checkin), false);
    });

    test('updateActivityConfig updates priority', () {
      final prefs = NotificationPreferences();
      final updated = prefs.updateActivityConfig(
        ActivityType.checkin,
        priority: NotificationPriority.critical,
      );
      expect(
        updated.getPriority(ActivityType.checkin),
        NotificationPriority.critical,
      );
      // Other types unchanged
      expect(
        updated.getPriority(ActivityType.momentPlanned),
        NotificationPriority.normal,
      );
    });

    test('toFirestore and fromFirestore round-trip correctly', () {
      final original = NotificationPreferences()
          .updateActivityConfig(
            ActivityType.checkin,
            priority: NotificationPriority.high,
          )
          .toggleActivityType(ActivityType.momentEdited);

      final json = original.toFirestore();
      final restored = NotificationPreferences.fromFirestore(json);

      expect(restored.globalEnabled, original.globalEnabled);
      expect(
        restored.getPriority(ActivityType.checkin),
        original.getPriority(ActivityType.checkin),
      );
      expect(
        restored.shouldNotify(ActivityType.momentEdited),
        original.shouldNotify(ActivityType.momentEdited),
      );
    });

    test('fromFirestore handles null data', () {
      final prefs = NotificationPreferences.fromFirestore(null);
      expect(prefs.globalEnabled, true);
      expect(prefs.activityConfigs.isNotEmpty, true);
    });
  });
}
