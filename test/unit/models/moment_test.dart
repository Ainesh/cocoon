/// Unit tests for the Moment model and related enums.
///
/// Covers: MOM-01 through MOM-33 from the test plan.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/moment.dart';
import '../../helpers/test_helpers.dart';

DateTime _todayUtc() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

void main() {
  // ===========================================================================
  // MomentType Enum
  // ===========================================================================

  group('MomentType', () {
    // MOM-01
    test('fromValue returns correct type for each known value', () {
      expect(MomentType.fromValue('celebrate'), MomentType.celebrate);
      expect(MomentType.fromValue('connect'), MomentType.connect);
      expect(MomentType.fromValue('escape'), MomentType.escape);
    });

    // MOM-02
    test('fromValue returns connect as default for unknown value', () {
      expect(MomentType.fromValue('unknown'), MomentType.connect);
      expect(MomentType.fromValue(''), MomentType.connect);
    });

    test('each type has emoji, label, and value', () {
      for (final type in MomentType.values) {
        expect(type.value, isNotEmpty);
        expect(type.label, isNotEmpty);
        expect(type.emoji, isNotEmpty);
      }
    });
  });

  // ===========================================================================
  // TimeSlot Enum
  // ===========================================================================

  group('TimeSlot', () {
    // MOM-03
    test('fromValue returns correct slot for each known value', () {
      expect(TimeSlot.fromValue('morning'), TimeSlot.morning);
      expect(TimeSlot.fromValue('afternoon'), TimeSlot.afternoon);
      expect(TimeSlot.fromValue('evening'), TimeSlot.evening);
      expect(TimeSlot.fromValue('night'), TimeSlot.night);
    });

    // MOM-04
    test('fromValue returns evening for unknown value', () {
      expect(TimeSlot.fromValue('unknown'), TimeSlot.evening);
      expect(TimeSlot.fromValue(''), TimeSlot.evening);
    });
  });

  // ===========================================================================
  // RepeatSchedule Enum
  // ===========================================================================

  group('RepeatSchedule', () {
    // MOM-05
    test('fromValue returns correct schedule for each known value', () {
      expect(RepeatSchedule.fromValue('never'), RepeatSchedule.never);
      expect(RepeatSchedule.fromValue('daily'), RepeatSchedule.daily);
      expect(RepeatSchedule.fromValue('weekly'), RepeatSchedule.weekly);
      expect(RepeatSchedule.fromValue('monthly'), RepeatSchedule.monthly);
      expect(RepeatSchedule.fromValue('yearly'), RepeatSchedule.yearly);
    });

    // MOM-06
    test('fromValue returns never for unknown value', () {
      expect(RepeatSchedule.fromValue('unknown'), RepeatSchedule.never);
      expect(RepeatSchedule.fromValue(''), RepeatSchedule.never);
    });
  });

  // ===========================================================================
  // Presets
  // ===========================================================================

  group('Presets', () {
    // MOM-07
    test('CelebratePresets.options has expected entries', () {
      expect(CelebratePresets.options, isNotEmpty);
      expect(CelebratePresets.options, contains('Birthday'));
      expect(CelebratePresets.options, contains('Anniversary'));
      expect(CelebratePresets.options.length, 8);
    });

    // MOM-08
    test('ConnectPresets.options has expected entries', () {
      expect(ConnectPresets.options, isNotEmpty);
      expect(ConnectPresets.options, contains('Date Night'));
      expect(ConnectPresets.options, contains('Coffee'));
      expect(ConnectPresets.options.length, 8);
    });

    // MOM-09
    test('EscapePresets.options has expected entries', () {
      expect(EscapePresets.options, isNotEmpty);
      expect(EscapePresets.options, contains('Weekend Getaway'));
      expect(EscapePresets.options, contains('Beach Trip'));
      expect(EscapePresets.options.length, 8);
    });
  });

  // ===========================================================================
  // Moment Model
  // ===========================================================================

  group('Moment', () {
    // MOM-10
    test('displayTitle prepends emoji to name', () {
      final moment = createTestMoment(
        name: 'Date Night',
        type: MomentType.connect,
      );
      expect(moment.displayTitle, '💕 Date Night');

      final celebrate = createTestMoment(
        name: 'Birthday',
        type: MomentType.celebrate,
      );
      expect(celebrate.displayTitle, '🎉 Birthday');
    });

    // MOM-11
    test('isToday returns true for today\'s date', () {
      final moment = createTestMoment(startDate: _todayUtc());
      expect(moment.isToday, isTrue);
    });

    // MOM-12
    test('isToday returns false for yesterday', () {
      final moment = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 1)),
      );
      expect(moment.isToday, isFalse);
    });

    // MOM-13
    test('spansToday returns true for multi-day moment spanning today', () {
      final now = _todayUtc();
      final moment = createTestMoment(
        type: MomentType.escape,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 2)),
      );
      expect(moment.spansToday, isTrue);
    });

    // MOM-14
    test('spansToday returns false for past multi-day moment', () {
      final moment = createTestMoment(
        type: MomentType.escape,
        startDate: _todayUtc().subtract(const Duration(days: 10)),
        endDate: _todayUtc().subtract(const Duration(days: 5)),
      );
      expect(moment.spansToday, isFalse);
    });

    // MOM-15
    test('isPast returns true for past dates', () {
      final moment = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 5)),
      );
      expect(moment.isPast, isTrue);
    });

    // MOM-16
    test('isPast uses endDate when available (Escape)', () {
      final moment = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 5)),
        endDate: _todayUtc().add(const Duration(days: 2)),
      );
      expect(moment.isPast, isFalse);
    });

    // MOM-17
    test('isUpcoming returns true for future dates', () {
      final moment = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 5)),
      );
      expect(moment.isUpcoming, isTrue);
    });

    // MOM-18
    test('durationDays returns 1 for single-day moment', () {
      final moment = createTestMoment(endDate: null);
      expect(moment.durationDays, 1);
    });

    // MOM-19
    test('durationDays calculates correctly for multi-day', () {
      final start = DateTime.utc(2026, 3, 1);
      final moment = createTestEscapeMoment(
        startDate: start,
        endDate: DateTime.utc(2026, 3, 4),
      );
      expect(moment.durationDays, 4); // 3 days difference + 1
    });

    // MOM-20
    test('nights returns 0 for single-day moment', () {
      final moment = createTestMoment(endDate: null);
      expect(moment.nights, 0);
    });

    test('nights calculates correctly for multi-day', () {
      final start = DateTime.utc(2026, 3, 1);
      final moment = createTestEscapeMoment(
        startDate: start,
        endDate: DateTime.utc(2026, 3, 4),
      );
      expect(moment.nights, 3);
    });

    // MOM-21
    test('dateDisplay shows range for Escape with endDate', () {
      final start = DateTime.utc(2026, 3, 1);
      final end = DateTime.utc(2026, 3, 4);
      final moment = createTestMoment(
        type: MomentType.escape,
        startDate: start,
        endDate: end,
      );
      expect(moment.dateDisplay, 'Mar 1 - Mar 4');
    });

    // MOM-22
    test('dateDisplay shows single date for Connect', () {
      final moment = createTestMoment(
        type: MomentType.connect,
        startDate: DateTime.utc(2026, 2, 15),
      );
      expect(moment.dateDisplay, 'Feb 15');
    });

    // MOM-23
    test('timeDisplay returns empty string when timeSlot is null', () {
      final moment = createTestMoment(timeSlot: null);
      expect(moment.timeDisplay, '');
    });

    test('timeDisplay returns emoji and label when timeSlot is set', () {
      final moment = createTestMoment(timeSlot: TimeSlot.evening);
      expect(moment.timeDisplay, contains('Evening'));
    });

    // MOM-24
    test('relativeDate returns "Today", "Tomorrow", "Yesterday" correctly', () {
      final today = createTestMoment(startDate: _todayUtc());
      expect(today.relativeDate, 'Today');

      final tomorrow = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 1)),
      );
      expect(tomorrow.relativeDate, 'Tomorrow');

      final yesterday = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 1)),
      );
      expect(yesterday.relativeDate, 'Yesterday');
    });

    // MOM-25
    test('relativeDate returns "In X days" for near-future', () {
      final moment = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 4)),
      );
      expect(moment.relativeDate, 'In 4 days');
    });

    // MOM-26
    test('relativeDate returns "Next week", "In X weeks" correctly', () {
      final nextWeek = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 8)),
      );
      expect(nextWeek.relativeDate, 'Next week');

      final twoWeeks = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 16)),
      );
      expect(twoWeeks.relativeDate, 'In 2 weeks');
    });

    // MOM-27
    test('relativeDate returns "Next month", "In X months" correctly', () {
      final nextMonth = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 32)),
      );
      expect(nextMonth.relativeDate, 'Next month');

      final threeMonths = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 95)),
      );
      expect(threeMonths.relativeDate, 'In 3 months');
    });

    // MOM-28
    test('relativeDate returns "X days ago" for near past', () {
      final moment = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 3)),
      );
      expect(moment.relativeDate, '3 days ago');
    });

    // MOM-29
    test('fromJson parses all fields correctly', () {
      final startDate = DateTime(2026, 3, 1);
      final json = createTestMomentJson(
        name: 'Movie Night',
        type: 'connect',
        startDate: startDate,
        timeSlot: 'evening',
        notes: 'Some notes',
        version: 2,
      );

      final moment = Moment.fromJson('test_id', json);

      expect(moment.id, 'test_id');
      expect(moment.name, 'Movie Night');
      expect(moment.type, MomentType.connect);
      expect(moment.startDate.year, 2026);
      expect(moment.startDate.month, 3);
      expect(moment.timeSlot, TimeSlot.evening);
      expect(moment.notes, 'Some notes');
      expect(moment.version, 2);
    });

    // MOM-30
    test('fromJson handles null/missing fields with defaults', () {
      final json = <String, dynamic>{
        'startDate': Timestamp.fromDate(_todayUtc()),
      };

      final moment = Moment.fromJson('test_id', json);

      expect(moment.name, '');
      expect(moment.type, MomentType.connect);
      expect(moment.repeatSchedule, RepeatSchedule.never);
      expect(moment.createdBy, '');
      expect(moment.version, 1);
      expect(moment.endDate, isNull);
      expect(moment.timeSlot, isNull);
      expect(moment.notes, isNull);
    });

    // MOM-31
    test('toJson produces correct Firestore-compatible map', () {
      final moment = createTestMoment(
        name: 'Date Night',
        type: MomentType.connect,
        timeSlot: TimeSlot.evening,
        repeatSchedule: RepeatSchedule.weekly,
        notes: 'Fun night',
      );

      final json = moment.toJson();

      expect(json['name'], 'Date Night');
      expect(json['type'], 'connect');
      expect(json['timeSlot'], 'evening');
      expect(json['repeatSchedule'], 'weekly');
      expect(json['notes'], 'Fun night');
      expect(json['startDate'], isA<Timestamp>());
      expect(json['version'], 1);
    });

    // MOM-32
    test('copyWith creates correct copy', () {
      final original = createTestMoment(name: 'Date Night', version: 1);
      final copy = original.copyWith(name: 'Movie Night', version: 2);

      expect(copy.name, 'Movie Night');
      expect(copy.version, 2);
      expect(copy.id, original.id); // unchanged
      expect(copy.type, original.type); // unchanged
    });

    // MOM-33
    test('version defaults to 1', () {
      final moment = createTestMoment();
      expect(moment.version, 1);
    });

    test('toString returns expected format', () {
      final moment = createTestMoment(name: 'Date Night');
      final str = moment.toString();
      expect(str, contains('Moment'));
      expect(str, contains('Date Night'));
    });
  });

  // ===========================================================================
  // Date normalization (timezone fix)
  // ===========================================================================

  group('Moment date normalization', () {
    test('fromJson normalizes dates to UTC midnight', () {
      final utcDate = DateTime.utc(2026, 3, 10);
      final json = <String, dynamic>{
        'name': 'Test',
        'type': 'connect',
        'startDate': Timestamp.fromDate(utcDate),
        'createdBy': 'user1',
        'version': 1,
      };

      final moment = Moment.fromJson('test-id', json);
      expect(moment.startDate.month, 3);
      expect(moment.startDate.day, 10);
      expect(moment.startDate.hour, 0);
      expect(moment.startDate.isUtc, true);
    });

    test('fromJson normalizes endDate to UTC midnight', () {
      final utcStart = DateTime.utc(2026, 3, 10);
      final utcEnd = DateTime.utc(2026, 3, 12);
      final json = <String, dynamic>{
        'name': 'Trip',
        'type': 'escape',
        'startDate': Timestamp.fromDate(utcStart),
        'endDate': Timestamp.fromDate(utcEnd),
        'createdBy': 'user1',
        'version': 1,
      };

      final moment = Moment.fromJson('test-id', json);
      expect(moment.startDate.day, 10);
      expect(moment.startDate.isUtc, true);
      expect(moment.endDate!.day, 12);
      expect(moment.endDate!.isUtc, true);
    });

    test('version field defaults to 1 when missing', () {
      final json = <String, dynamic>{
        'name': 'Test',
        'type': 'connect',
        'startDate': Timestamp.fromDate(DateTime(2026, 3, 10)),
        'createdBy': 'user1',
      };
      final moment = Moment.fromJson('test-id', json);
      expect(moment.version, 1);
    });

    test('version field is included in toJson', () {
      final moment = createTestMoment(version: 3);
      final json = moment.toJson();
      expect(json['version'], 3);
    });
  });
}
