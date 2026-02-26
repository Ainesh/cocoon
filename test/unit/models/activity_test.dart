/// Unit tests for the Activity model and related enums.
///
/// Covers: ACT-01 through ACT-22 from the test plan.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/activity.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ===========================================================================
  // ActivityType Enum
  // ===========================================================================

  group('ActivityType', () {
    // ACT-01
    test('fromValue returns correct type for each known value', () {
      expect(ActivityType.fromValue('checkin'), ActivityType.checkin);
      expect(
        ActivityType.fromValue('moment_planned'),
        ActivityType.momentPlanned,
      );
      expect(
        ActivityType.fromValue('moment_edited'),
        ActivityType.momentEdited,
      );
      expect(
        ActivityType.fromValue('moment_deleted'),
        ActivityType.momentDeleted,
      );
      expect(
        ActivityType.fromValue('moment_completed'),
        ActivityType.momentCompleted,
      );
      expect(
        ActivityType.fromValue('space_created'),
        ActivityType.spaceCreated,
      );
      expect(ActivityType.fromValue('space_joined'), ActivityType.spaceJoined);
      expect(
        ActivityType.fromValue('space_renamed'),
        ActivityType.spaceRenamed,
      );
      expect(ActivityType.fromValue('invite_sent'), ActivityType.inviteSent);
      expect(
        ActivityType.fromValue('invite_accepted'),
        ActivityType.inviteAccepted,
      );
    });

    // ACT-02
    test('fromValue returns checkin for unknown value', () {
      expect(ActivityType.fromValue('unknown'), ActivityType.checkin);
      expect(ActivityType.fromValue(''), ActivityType.checkin);
      expect(ActivityType.fromValue('invalid_type'), ActivityType.checkin);
    });

    // ACT-03
    test('isMomentActivity returns true for moment-related types', () {
      expect(ActivityType.momentPlanned.isMomentActivity, isTrue);
      expect(ActivityType.momentEdited.isMomentActivity, isTrue);
      expect(ActivityType.momentDeleted.isMomentActivity, isTrue);
      expect(ActivityType.momentCompleted.isMomentActivity, isTrue);
    });

    // ACT-04
    test('isMomentActivity returns false for non-moment types', () {
      expect(ActivityType.checkin.isMomentActivity, isFalse);
      expect(ActivityType.spaceCreated.isMomentActivity, isFalse);
      expect(ActivityType.spaceJoined.isMomentActivity, isFalse);
      expect(ActivityType.inviteSent.isMomentActivity, isFalse);
    });

    // ACT-05
    test('isSpaceActivity returns true for space-related types', () {
      expect(ActivityType.spaceCreated.isSpaceActivity, isTrue);
      expect(ActivityType.spaceJoined.isSpaceActivity, isTrue);
      expect(ActivityType.spaceRenamed.isSpaceActivity, isTrue);
      expect(ActivityType.inviteSent.isSpaceActivity, isTrue);
      expect(ActivityType.inviteAccepted.isSpaceActivity, isTrue);
    });
  });

  // ===========================================================================
  // EntityType Enum
  // ===========================================================================

  group('EntityType', () {
    // ACT-06
    test('fromValue returns correct type for each known value', () {
      expect(EntityType.fromValue('checkin'), EntityType.checkin);
      expect(EntityType.fromValue('moment'), EntityType.moment);
      expect(EntityType.fromValue('space'), EntityType.space);
    });

    // ACT-07
    test('fromValue returns space for unknown value', () {
      expect(EntityType.fromValue('unknown'), EntityType.space);
      expect(EntityType.fromValue(''), EntityType.space);
    });
  });

  // ===========================================================================
  // Activity Model
  // ===========================================================================

  group('Activity', () {
    // ACT-08
    test('description returns correct text for each ActivityType', () {
      final checkinActivity = createTestActivity(type: ActivityType.checkin);
      expect(checkinActivity.description, 'checked in');

      final spaceCreated = createTestActivity(type: ActivityType.spaceCreated);
      expect(spaceCreated.description, 'created the space');

      final spaceJoined = createTestActivity(type: ActivityType.spaceJoined);
      expect(spaceJoined.description, 'joined the space');
    });

    // ACT-09
    test('description includes moment name from metadata when present', () {
      final activity = createTestActivity(
        type: ActivityType.momentPlanned,
        metadata: {'momentName': 'Date Night'},
      );
      expect(activity.description, 'planned "Date Night"');
    });

    // ACT-10
    test('description handles missing metadata gracefully', () {
      final activity = createTestActivity(type: ActivityType.momentPlanned);
      expect(activity.description, 'planned');

      final edited = createTestActivity(type: ActivityType.momentEdited);
      expect(edited.description, 'updated a moment');
    });

    // ACT-11
    test('relativeTime returns "Just now" for < 1 minute', () {
      final activity = createTestActivity(timestamp: DateTime.now());
      expect(activity.relativeTime, 'Just now');
    });

    // ACT-12
    test(
      'relativeTime returns correct format for hours, days, weeks, months',
      () {
        final hoursAgo = createTestActivity(
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        );
        expect(hoursAgo.relativeTime, '3h ago');

        final daysAgo = createTestActivity(
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        );
        expect(daysAgo.relativeTime, '2d ago');

        final yesterday = createTestActivity(
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(yesterday.relativeTime, 'Yesterday');

        final weeksAgo = createTestActivity(
          timestamp: DateTime.now().subtract(const Duration(days: 14)),
        );
        expect(weeksAgo.relativeTime, '2w ago');

        final monthsAgo = createTestActivity(
          timestamp: DateTime.now().subtract(const Duration(days: 60)),
        );
        expect(monthsAgo.relativeTime, '2mo ago');
      },
    );

    // ACT-13
    test('isNavigable returns true when entityId present and not deleted', () {
      final activity = createTestActivity(
        type: ActivityType.momentPlanned,
        entityId: 'moment_1',
      );
      expect(activity.isNavigable, isTrue);
    });

    // ACT-14
    test('isNavigable returns false for deleted moments', () {
      final activity = createTestActivity(
        type: ActivityType.momentDeleted,
        entityId: 'moment_1',
      );
      expect(activity.isNavigable, isFalse);
    });

    // ACT-15
    test('isNavigable returns false when entityId is null', () {
      final activity = createTestActivity(entityId: null);
      expect(activity.isNavigable, isFalse);
    });

    // ACT-16
    test('toFirestore produces correct map structure', () {
      final activity = createTestActivity(
        type: ActivityType.checkin,
        actorId: 'user_1',
        actorName: 'Alex',
        entityType: EntityType.checkin,
        entityId: 'checkin_1',
        metadata: {'connection': 7},
      );

      final map = activity.toFirestore();

      expect(map['type'], 'checkin');
      expect(map['actorId'], 'user_1');
      expect(map['actorName'], 'Alex');
      expect(map['entityType'], 'checkin');
      expect(map['entityId'], 'checkin_1');
      expect(map['metadata'], {'connection': 7});
      expect(map.containsKey('timestamp'), isTrue);
    });

    // ACT-17
    test('toFirestore omits null optional fields', () {
      final activity = createTestActivity(
        entityType: null,
        entityId: null,
        metadata: null,
      );

      final map = activity.toFirestore();

      expect(map.containsKey('entityType'), isFalse);
      expect(map.containsKey('entityId'), isFalse);
      expect(map.containsKey('metadata'), isFalse);
    });

    // ACT-20
    test('copyWith creates correct copy with overridden fields', () {
      final original = createTestActivity(
        id: 'act_1',
        actorName: 'Alex',
        type: ActivityType.checkin,
      );

      final copy = original.copyWith(
        actorName: 'Jordan',
        type: ActivityType.momentPlanned,
      );

      expect(copy.id, 'act_1'); // unchanged
      expect(copy.actorName, 'Jordan');
      expect(copy.type, ActivityType.momentPlanned);
    });

    // ACT-21
    test('changedFields returns list for momentEdited type', () {
      final activity = createTestActivity(
        type: ActivityType.momentEdited,
        metadata: {
          'changedFields': ['date', 'time', 'notes'],
        },
      );
      expect(activity.changedFields, ['date', 'time', 'notes']);
    });

    // ACT-22
    test('changedFields returns empty list for non-edited types', () {
      final activity = createTestActivity(type: ActivityType.checkin);
      expect(activity.changedFields, isEmpty);

      final planned = createTestActivity(type: ActivityType.momentPlanned);
      expect(planned.changedFields, isEmpty);
    });

    test('description for spaceRenamed includes new name from metadata', () {
      final activity = createTestActivity(
        type: ActivityType.spaceRenamed,
        metadata: {'newName': 'Our Kairos'},
      );
      expect(activity.description, 'renamed space to "Our Kairos"');
    });

    test('description for momentEdited includes moment name', () {
      final activity = createTestActivity(
        type: ActivityType.momentEdited,
        metadata: {'momentName': 'Movie Night'},
      );
      expect(activity.description, 'updated "Movie Night"');
    });

    test('toString returns expected format', () {
      final activity = createTestActivity(
        id: 'act_1',
        type: ActivityType.checkin,
        actorName: 'Alex',
      );
      expect(activity.toString(), contains('Activity'));
      expect(activity.toString(), contains('act_1'));
    });
  });
}
