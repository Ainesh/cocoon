import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/activity.dart';

void main() {
  group('ActivityType', () {
    test('fromValue returns correct type for all values', () {
      expect(ActivityType.fromValue('checkin'), ActivityType.checkin);
      expect(ActivityType.fromValue('moment_planned'), ActivityType.momentPlanned);
      expect(ActivityType.fromValue('moment_edited'), ActivityType.momentEdited);
      expect(ActivityType.fromValue('moment_deleted'), ActivityType.momentDeleted);
      expect(ActivityType.fromValue('moment_completed'), ActivityType.momentCompleted);
      expect(ActivityType.fromValue('space_created'), ActivityType.spaceCreated);
      expect(ActivityType.fromValue('space_joined'), ActivityType.spaceJoined);
      expect(ActivityType.fromValue('space_renamed'), ActivityType.spaceRenamed);
      expect(ActivityType.fromValue('invite_sent'), ActivityType.inviteSent);
      expect(ActivityType.fromValue('invite_accepted'), ActivityType.inviteAccepted);
    });

    test('fromValue defaults to checkin for unknown values', () {
      expect(ActivityType.fromValue('unknown'), ActivityType.checkin);
      expect(ActivityType.fromValue(''), ActivityType.checkin);
    });

    test('isMomentActivity returns true for moment types only', () {
      expect(ActivityType.momentPlanned.isMomentActivity, true);
      expect(ActivityType.momentEdited.isMomentActivity, true);
      expect(ActivityType.momentDeleted.isMomentActivity, true);
      expect(ActivityType.momentCompleted.isMomentActivity, true);
      expect(ActivityType.checkin.isMomentActivity, false);
      expect(ActivityType.spaceJoined.isMomentActivity, false);
    });

    test('isSpaceActivity returns true for space types only', () {
      expect(ActivityType.spaceCreated.isSpaceActivity, true);
      expect(ActivityType.spaceJoined.isSpaceActivity, true);
      expect(ActivityType.spaceRenamed.isSpaceActivity, true);
      expect(ActivityType.checkin.isSpaceActivity, false);
      expect(ActivityType.momentPlanned.isSpaceActivity, false);
    });
  });

  group('EntityType', () {
    test('fromValue returns correct type', () {
      expect(EntityType.fromValue('checkin'), EntityType.checkin);
      expect(EntityType.fromValue('moment'), EntityType.moment);
      expect(EntityType.fromValue('space'), EntityType.space);
    });

    test('fromValue defaults to space for unknown values', () {
      expect(EntityType.fromValue('unknown'), EntityType.space);
    });
  });

  group('Activity.isNavigable', () {
    Activity _makeActivity({
      ActivityType type = ActivityType.momentPlanned,
      String? entityId,
    }) {
      return Activity(
        id: 'test',
        type: type,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
        entityType: EntityType.moment,
        entityId: entityId,
      );
    }

    test('returns true for moment_planned with entityId', () {
      expect(_makeActivity(entityId: 'mom123').isNavigable, true);
    });

    test('returns true for moment_edited with entityId', () {
      expect(
        _makeActivity(type: ActivityType.momentEdited, entityId: 'mom123').isNavigable,
        true,
      );
    });

    test('returns false for moment_deleted even with entityId', () {
      expect(
        _makeActivity(type: ActivityType.momentDeleted, entityId: 'mom123').isNavigable,
        false,
      );
    });

    test('returns false when entityId is null', () {
      expect(_makeActivity(entityId: null).isNavigable, false);
    });

    test('returns false when entityId is empty string', () {
      expect(_makeActivity(entityId: '').isNavigable, false);
    });

    test('returns true for checkin with entityId', () {
      expect(
        _makeActivity(type: ActivityType.checkin, entityId: 'chk123').isNavigable,
        true,
      );
    });

    test('returns true for space_joined with entityId', () {
      expect(
        _makeActivity(type: ActivityType.spaceJoined, entityId: 'space1').isNavigable,
        true,
      );
    });
  });

  group('Activity.description', () {
    Activity _makeActivity({
      required ActivityType type,
      Map<String, dynamic>? metadata,
    }) {
      return Activity(
        id: 'test',
        type: type,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
        metadata: metadata,
      );
    }

    test('checkin returns "checked in"', () {
      expect(_makeActivity(type: ActivityType.checkin).description, 'checked in');
    });

    test('moment_planned with name includes quoted name', () {
      final activity = _makeActivity(
        type: ActivityType.momentPlanned,
        metadata: {'momentName': 'Date Night'},
      );
      expect(activity.description, contains('"Date Night"'));
    });

    test('moment_planned without name uses action text', () {
      final activity = _makeActivity(type: ActivityType.momentPlanned);
      expect(activity.description, ActivityType.momentPlanned.actionText);
    });

    test('moment_edited with name says "updated"', () {
      final activity = _makeActivity(
        type: ActivityType.momentEdited,
        metadata: {'momentName': 'Dinner'},
      );
      expect(activity.description, 'updated "Dinner"');
    });

    test('space_renamed with newName includes name', () {
      final activity = _makeActivity(
        type: ActivityType.spaceRenamed,
        metadata: {'newName': 'Our Space'},
      );
      expect(activity.description, contains('"Our Space"'));
    });
  });

  group('Activity.changedFields', () {
    test('returns list for moment_edited with changedFields', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.momentEdited,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
        metadata: {
          'changedFields': ['date', 'time', 'notes'],
        },
      );
      expect(activity.changedFields, ['date', 'time', 'notes']);
    });

    test('returns empty for non-edited types', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.momentPlanned,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
      );
      expect(activity.changedFields, isEmpty);
    });

    test('returns empty when changedFields metadata is missing', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.momentEdited,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
        metadata: {},
      );
      expect(activity.changedFields, isEmpty);
    });
  });

  group('Activity.relativeTime', () {
    test('returns "Just now" for recent timestamps', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now(),
      );
      expect(activity.relativeTime, 'Just now');
    });

    test('returns minutes ago for < 1 hour', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(activity.relativeTime, '30m ago');
    });

    test('returns hours ago for < 24 hours', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(activity.relativeTime, '5h ago');
    });

    test('returns "Yesterday" for 1 day ago', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(activity.relativeTime, 'Yesterday');
    });

    test('returns days ago for < 7 days', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now().subtract(const Duration(days: 4)),
      );
      expect(activity.relativeTime, '4d ago');
    });

    test('returns weeks ago for < 30 days', () {
      final activity = Activity(
        id: 'test',
        type: ActivityType.checkin,
        actorId: 'user1',
        actorName: 'Test',
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(activity.relativeTime, '2w ago');
    });
  });
}
