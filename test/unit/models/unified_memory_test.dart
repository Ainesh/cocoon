import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/memory.dart';
import 'package:couple_space/models/moment.dart';
import '../../../test/helpers/test_helpers.dart';

DateTime _todayUtc() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

void main() {
  // ===========================================================================
  // Moment status field
  // ===========================================================================

  group('Moment status field', () {
    test('defaults to planned when not specified', () {
      final m = createTestMoment();
      expect(m.status, MomentStatus.planned);
    });

    test('fromJson defaults to planned when status field is missing', () {
      final json = createTestMomentJson();
      final m = Moment.fromJson('id', json);
      expect(m.status, MomentStatus.planned);
    });

    test('fromJson parses cancelled status', () {
      final json = createTestMomentJson();
      json['status'] = 'cancelled';
      final m = Moment.fromJson('id', json);
      expect(m.status, MomentStatus.cancelled);
    });

    test('fromJson maps legacy lived status to planned', () {
      final json = createTestMomentJson();
      json['status'] = 'lived';
      final m = Moment.fromJson('id', json);
      expect(m.status, MomentStatus.planned);
    });

    test('fromJson maps legacy missed status to cancelled', () {
      final json = createTestMomentJson();
      json['status'] = 'missed';
      final m = Moment.fromJson('id', json);
      expect(m.status, MomentStatus.cancelled);
    });

    test('fromJson defaults unknown status to planned', () {
      final json = createTestMomentJson();
      json['status'] = 'invalid';
      final m = Moment.fromJson('id', json);
      expect(m.status, MomentStatus.planned);
    });

    test('toJson includes status field', () {
      final m = createTestMoment(status: MomentStatus.cancelled);
      final json = m.toJson();
      expect(json['status'], 'cancelled');
    });

    test('copyWith updates status', () {
      final m = createTestMoment();
      final updated = m.copyWith(status: MomentStatus.cancelled);
      expect(updated.status, MomentStatus.cancelled);
      expect(m.status, MomentStatus.planned);
    });
  });

  // ===========================================================================
  // Memory — denormalized moment fields
  // ===========================================================================

  group('Memory denormalized moment fields', () {
    test('createTestMemory includes all moment fields', () {
      final m = createTestRichMemory();
      expect(m.momentId, isNotNull);
      expect(m.momentName, 'Date Night');
      expect(m.momentType, 'connect');
      expect(m.momentDate, isNotNull);
      expect(m.momentNotes, 'Try the new place');
      expect(m.momentTimeSlot, 'evening');
    });

    test('standalone memory has null moment fields', () {
      final m = createTestStandaloneMemory();
      expect(m.momentId, isNull);
      expect(m.momentName, isNull);
      expect(m.momentType, isNull);
      expect(m.isStandalone, true);
      expect(m.title, 'Surprise Picnic');
    });

    test('displayTitle returns momentName for linked memories', () {
      final m = createTestMemory(momentName: 'Anniversary');
      expect(m.displayTitle, 'Anniversary');
    });

    test('displayTitle returns title for standalone memories', () {
      final m = createTestStandaloneMemory(title: 'Road Trip');
      expect(m.displayTitle, 'Road Trip');
    });
  });

  // ===========================================================================
  // Memory — content detection
  // ===========================================================================

  group('Memory content detection', () {
    test('hasContent is false for empty memory', () {
      final m = createTestMemory();
      expect(m.hasContent, false);
    });

    test('hasContent is true when photos are present', () {
      final m = createTestMemory(photoPaths: ['path/photo.jpg']);
      expect(m.hasContent, true);
    });

    test('hasContent is true when caption is present', () {
      final m = createTestMemory(caption: 'Great time');
      expect(m.hasContent, true);
    });

    test('hasContent is true when place is present', () {
      final m = createTestMemory(place: 'Downtown');
      expect(m.hasContent, true);
    });

    test('hasContent is true when music is present', () {
      final m = createTestMemory(music: 'A song');
      expect(m.hasContent, true);
    });

    test('hasContent is true when checkinId is present', () {
      final m = createTestMemory(checkinId: 'checkin_1');
      expect(m.hasContent, true);
    });

    test('rich memory has all content flags true', () {
      final m = createTestRichMemory();
      expect(m.hasContent, true);
      expect(m.hasPhotos, true);
      expect(m.hasCaption, true);
      expect(m.hasPlace, true);
      expect(m.hasMusic, true);
      expect(m.hasCheckin, true);
    });
  });

  // ===========================================================================
  // Memory — serialization round-trip with new fields
  // ===========================================================================

  group('Memory serialization with new fields', () {
    test('toJson includes all denormalized fields', () {
      final m = createTestRichMemory();
      final json = m.toJson();

      expect(json['momentNotes'], 'Try the new place');
      expect(json['momentTimeSlot'], 'evening');
      expect(json.containsKey('momentEndDate'), false);
    });

    test('fromJson parses all denormalized fields', () {
      final json = <String, dynamic>{
        'momentId': 'mom_1',
        'momentName': 'Trip',
        'momentType': 'escape',
        'momentDate': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'momentEndDate': Timestamp.fromDate(DateTime.utc(2026, 3, 5)),
        'momentTimeSlot': 'morning',
        'momentNotes': 'Pack bags',
        'createdBy': 'user_1',
        'photoPaths': <String>[],
        'thumbPaths': <String>[],
        'reactions': <String, String>{},
        'date': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final m = Memory.fromJson('id', json);
      expect(m.momentEndDate, isNotNull);
      expect(m.momentEndDate!.year, 2026);
      expect(m.momentEndDate!.month, 3);
      expect(m.momentTimeSlot, 'morning');
      expect(m.momentNotes, 'Pack bags');
    });

    test('new fields default to null for backward compat', () {
      final json = <String, dynamic>{
        'createdBy': 'user_1',
        'photoPaths': <String>[],
        'thumbPaths': <String>[],
        'reactions': <String, String>{},
        'date': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final m = Memory.fromJson('id', json);
      expect(m.momentEndDate, isNull);
      expect(m.momentTimeSlot, isNull);
      expect(m.momentNotes, isNull);
    });
  });

  // ===========================================================================
  // Memory — reactions
  // ===========================================================================

  group('Memory reactions', () {
    test('reactions map is empty by default', () {
      final m = createTestMemory();
      expect(m.reactions, isEmpty);
    });

    test('reactions map stores userId to emoji', () {
      final m = createTestMemory(reactions: {'user_2': '❤️', 'user_3': '🔥'});
      expect(m.reactions['user_2'], '❤️');
      expect(m.reactions['user_3'], '🔥');
      expect(m.reactions.length, 2);
    });

    test('reactions round-trip through toJson/fromJson', () {
      final original = createTestMemory(reactions: {'user_2': '🥹'});
      final json = original.toJson();
      json['createdAt'] = Timestamp.fromDate(DateTime.now());
      final parsed = Memory.fromJson('id', json);
      expect(parsed.reactions['user_2'], '🥹');
    });
  });

  // ===========================================================================
  // Prompt eligibility — unified flow
  // ===========================================================================

  group('Prompt eligibility for unified flow', () {
    List<Moment> filterForPrompt(List<Moment> moments) {
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final cutoff = today.subtract(const Duration(days: 14));

      return moments
          .where((m) {
            if (m.status != MomentStatus.planned) return false;
            if (m.type == MomentType.external) return false;
            final effectiveEnd = m.endDate ?? m.startDate;
            return effectiveEnd.isBefore(today) && effectiveEnd.isAfter(cutoff);
          })
          .toList()
        ..sort((a, b) =>
            (b.endDate ?? b.startDate).compareTo(a.endDate ?? a.startDate));
    }

    test('past planned moment is eligible', () {
      final m = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 2)),
        endDate: _todayUtc().subtract(const Duration(days: 2)),
      );
      expect(filterForPrompt([m]), hasLength(1));
    });

    test('past cancelled moment is NOT eligible', () {
      final m = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 2)),
        status: MomentStatus.cancelled,
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('external moments are excluded', () {
      final m = createTestMoment(
        type: MomentType.external,
        startDate: _todayUtc().subtract(const Duration(days: 2)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('moment older than 14 days is excluded', () {
      final m = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 20)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('future moment is excluded', () {
      final m = createTestMoment(
        startDate: _todayUtc().add(const Duration(days: 3)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('cancelled moment is excluded from prompt', () {
      final m = createTestMoment(
        startDate: _todayUtc().subtract(const Duration(days: 2)),
      );
      expect(filterForPrompt([m]), hasLength(1));

      final afterCancelled = m.copyWith(status: MomentStatus.cancelled);
      expect(filterForPrompt([afterCancelled]), isEmpty);
    });

    test('moment with endDate uses endDate for past check (escape)', () {
      final m = createTestMoment(
        type: MomentType.escape,
        startDate: _todayUtc().subtract(const Duration(days: 10)),
        endDate: _todayUtc().subtract(const Duration(days: 3)),
      );
      expect(filterForPrompt([m]), hasLength(1));
    });

    test('ongoing escape (endDate in future) is excluded', () {
      final m = createTestMoment(
        type: MomentType.escape,
        startDate: _todayUtc().subtract(const Duration(days: 3)),
        endDate: _todayUtc().add(const Duration(days: 2)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });
  });

  // ===========================================================================
  // Memory doc ID convention
  // ===========================================================================

  group('Memory document ID convention', () {
    test('moment-linked ID is momentId_userId', () {
      final id = '${createTestMoment().id}_user_1';
      expect(id, 'moment_1_user_1');
    });

    test('enforces 1 memory per user per moment by ID', () {
      final m1 = createTestMemory(id: 'moment_1_user_1', createdBy: 'user_1');
      final m2 = createTestMemory(id: 'moment_1_user_2', createdBy: 'user_2');
      expect(m1.id, isNot(m2.id));
      expect(m1.momentId, m2.momentId);
    });
  });

  // ===========================================================================
  // MemoryReactions curated set
  // ===========================================================================

  group('MemoryReactions', () {
    test('has exactly 6 curated options', () {
      expect(MemoryReactions.options.length, 6);
    });

    test('each option has emoji and label', () {
      for (final option in MemoryReactions.options) {
        expect(option.emoji, isNotEmpty);
        expect(option.label, isNotEmpty);
      }
    });

    test('includes expected emojis', () {
      final emojis = MemoryReactions.options.map((o) => o.emoji).toSet();
      expect(emojis, contains('❤️'));
      expect(emojis, contains('🔥'));
      expect(emojis, contains('✨'));
    });
  });
}
