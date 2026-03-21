import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/memory.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MomentStatus
  // ---------------------------------------------------------------------------

  group('MomentStatus', () {
    test('fromValue returns correct status for current values', () {
      expect(MomentStatus.fromValue('planned'), MomentStatus.planned);
      expect(MomentStatus.fromValue('cancelled'), MomentStatus.cancelled);
    });

    test('fromValue maps legacy values correctly', () {
      expect(MomentStatus.fromValue('lived'), MomentStatus.planned);
      expect(MomentStatus.fromValue('missed'), MomentStatus.cancelled);
    });

    test('fromValue defaults to planned for unknown values', () {
      expect(MomentStatus.fromValue('unknown'), MomentStatus.planned);
      expect(MomentStatus.fromValue(''), MomentStatus.planned);
    });

    test('value property round-trips correctly', () {
      for (final status in MomentStatus.values) {
        expect(MomentStatus.fromValue(status.value), status);
      }
    });
  });

  group('MemorySentiment', () {
    test('fromValue returns correct sentiment', () {
      expect(MemorySentiment.fromValue('lived'), MemorySentiment.lived);
      expect(MemorySentiment.fromValue('missed'), MemorySentiment.missed);
    });

    test('fromValue returns null for unknown or null values', () {
      expect(MemorySentiment.fromValue(null), isNull);
      expect(MemorySentiment.fromValue('unknown'), isNull);
    });

    test('value property round-trips correctly', () {
      for (final s in MemorySentiment.values) {
        expect(MemorySentiment.fromValue(s.value), s);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // MemoryReactions
  // ---------------------------------------------------------------------------

  group('MemoryReactions', () {
    test('has exactly 6 curated reaction options', () {
      expect(MemoryReactions.options.length, 6);
    });

    test('each option has non-empty emoji and label', () {
      for (final option in MemoryReactions.options) {
        expect(option.emoji, isNotEmpty);
        expect(option.label, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Memory — fromJson
  // ---------------------------------------------------------------------------

  group('Memory.fromJson', () {
    test('parses a fully populated moment-linked memory', () {
      final json = _fullMomentLinkedJson();
      final memory = Memory.fromJson('mem_123', json);

      expect(memory.id, 'mem_123');
      expect(memory.momentId, 'mom_456');
      expect(memory.momentName, 'Date Night');
      expect(memory.momentType, 'connect');
      expect(memory.momentDate, isNotNull);
      expect(memory.title, isNull);
      expect(memory.createdBy, 'user_abc');
      expect(memory.photoPaths, ['path/photo_0.jpg', 'path/photo_1.jpg']);
      expect(memory.thumbPaths, ['path/photo_0_thumb.jpg', 'path/photo_1_thumb.jpg']);
      expect(memory.caption, 'Great evening!');
      expect(memory.place, 'Downtown');
      expect(memory.music, 'Something by The Beatles');
      expect(memory.checkinId, 'checkin_789');
      expect(memory.reactions, {'user_def': '❤️'});
      expect(memory.isStandalone, false);
      expect(memory.hasPhotos, true);
      expect(memory.hasCheckin, true);
      expect(memory.hasCaption, true);
      expect(memory.hasPlace, true);
      expect(memory.hasMusic, true);
      expect(memory.displayTitle, 'Date Night');
    });

    test('parses a standalone memory', () {
      final json = _standaloneJson();
      final memory = Memory.fromJson('mem_standalone', json);

      expect(memory.id, 'mem_standalone');
      expect(memory.momentId, isNull);
      expect(memory.momentName, isNull);
      expect(memory.title, 'Surprise picnic');
      expect(memory.isStandalone, true);
      expect(memory.displayTitle, 'Surprise picnic');
    });

    test('parses a minimal memory (all optional fields absent)', () {
      final json = _minimalJson();
      final memory = Memory.fromJson('mem_min', json);

      expect(memory.id, 'mem_min');
      expect(memory.createdBy, 'user_abc');
      expect(memory.momentId, isNull);
      expect(memory.title, isNull);
      expect(memory.photoPaths, isEmpty);
      expect(memory.thumbPaths, isEmpty);
      expect(memory.caption, isNull);
      expect(memory.place, isNull);
      expect(memory.music, isNull);
      expect(memory.checkinId, isNull);
      expect(memory.reactions, isEmpty);
      expect(memory.updatedAt, isNull);
      expect(memory.hasPhotos, false);
      expect(memory.hasCheckin, false);
      expect(memory.hasCaption, false);
      expect(memory.isEdited, false);
    });

    test('handles null photoUrls gracefully (legacy compat)', () {
      final json = _minimalJson();
      json.remove('photoPaths');
      json.remove('thumbPaths');
      final memory = Memory.fromJson('id', json);
      expect(memory.photoPaths, isEmpty);
      expect(memory.thumbPaths, isEmpty);
    });

    test('parses updatedAt when present', () {
      final json = _fullMomentLinkedJson();
      json['updatedAt'] = Timestamp.fromDate(DateTime(2026, 3, 14));
      final memory = Memory.fromJson('id', json);
      expect(memory.updatedAt, isNotNull);
      expect(memory.isEdited, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Memory — toJson
  // ---------------------------------------------------------------------------

  group('Memory.toJson', () {
    test('includes all non-null fields for a full memory', () {
      final memory = _fullMemory();
      final json = memory.toJson();

      expect(json['momentId'], 'mom_456');
      expect(json['momentName'], 'Date Night');
      expect(json['momentType'], 'connect');
      expect(json['momentDate'], isA<Timestamp>());
      expect(json['createdBy'], 'user_abc');
      expect(json['photoPaths'], hasLength(2));
      expect(json['thumbPaths'], hasLength(2));
      expect(json['caption'], 'Great evening!');
      expect(json['place'], 'Downtown');
      expect(json['music'], 'Something by The Beatles');
      expect(json['checkinId'], 'checkin_789');
      expect(json['reactions'], isA<Map>());
      expect(json['date'], isA<Timestamp>());
      expect(json['createdAt'], isA<FieldValue>());
      expect(json.containsKey('title'), false);
      expect(json.containsKey('updatedAt'), false);
    });

    test('omits null optional fields', () {
      final memory = _minimalMemory();
      final json = memory.toJson();

      expect(json.containsKey('momentId'), false);
      expect(json.containsKey('momentName'), false);
      expect(json.containsKey('momentType'), false);
      expect(json.containsKey('momentDate'), false);
      expect(json.containsKey('title'), false);
      expect(json.containsKey('caption'), false);
      expect(json.containsKey('place'), false);
      expect(json.containsKey('music'), false);
      expect(json.containsKey('checkinId'), false);
      expect(json['photoPaths'], isEmpty);
      expect(json['thumbPaths'], isEmpty);
      expect(json['reactions'], isEmpty);
    });

    test('includes title for standalone memories', () {
      final memory = _minimalMemory().copyWith(title: 'My Title');
      final json = memory.toJson();
      expect(json['title'], 'My Title');
    });
  });

  // ---------------------------------------------------------------------------
  // Memory — toUpdateJson
  // ---------------------------------------------------------------------------

  group('Memory.toUpdateJson', () {
    test('includes editable fields and updatedAt', () {
      final memory = _fullMemory();
      final json = memory.toUpdateJson();

      expect(json['photoPaths'], hasLength(2));
      expect(json['thumbPaths'], hasLength(2));
      expect(json['caption'], 'Great evening!');
      expect(json['place'], 'Downtown');
      expect(json['music'], 'Something by The Beatles');
      expect(json['updatedAt'], isA<FieldValue>());
    });

    test('never includes createdAt, createdBy, reactions, checkinId, moment fields', () {
      final memory = _fullMemory();
      final json = memory.toUpdateJson();

      expect(json.containsKey('createdAt'), false);
      expect(json.containsKey('createdBy'), false);
      expect(json.containsKey('reactions'), false);
      expect(json.containsKey('checkinId'), false);
      expect(json.containsKey('momentId'), false);
      expect(json.containsKey('momentName'), false);
      expect(json.containsKey('momentType'), false);
      expect(json.containsKey('momentDate'), false);
      expect(json.containsKey('date'), false);
    });

    test('uses FieldValue.delete() for null optional text fields', () {
      final memory = _minimalMemory();
      final json = memory.toUpdateJson();

      expect(json['caption'], isA<FieldValue>());
      expect(json['place'], isA<FieldValue>());
      expect(json['music'], isA<FieldValue>());
    });
  });

  // ---------------------------------------------------------------------------
  // Memory — copyWith
  // ---------------------------------------------------------------------------

  group('Memory.copyWith', () {
    test('creates independent copy with changed fields', () {
      final original = _fullMemory();
      final copy = original.copyWith(caption: 'Updated caption');

      expect(copy.caption, 'Updated caption');
      expect(copy.id, original.id);
      expect(copy.momentId, original.momentId);
      expect(copy.createdBy, original.createdBy);
      expect(original.caption, 'Great evening!');
    });

    test('preserves all fields when no arguments provided', () {
      final original = _fullMemory();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.momentId, original.momentId);
      expect(copy.momentName, original.momentName);
      expect(copy.momentType, original.momentType);
      expect(copy.title, original.title);
      expect(copy.createdBy, original.createdBy);
      expect(copy.photoPaths, original.photoPaths);
      expect(copy.thumbPaths, original.thumbPaths);
      expect(copy.caption, original.caption);
      expect(copy.place, original.place);
      expect(copy.music, original.music);
      expect(copy.checkinId, original.checkinId);
      expect(copy.reactions, original.reactions);
    });
  });

  // ---------------------------------------------------------------------------
  // Memory — computed properties
  // ---------------------------------------------------------------------------

  group('Memory computed properties', () {
    test('isStandalone is true when momentId is null', () {
      expect(_minimalMemory().isStandalone, true);
    });

    test('isStandalone is false when momentId is present', () {
      expect(_fullMemory().isStandalone, false);
    });

    test('displayTitle returns momentName for linked memories', () {
      expect(_fullMemory().displayTitle, 'Date Night');
    });

    test('displayTitle returns title for standalone memories', () {
      final m = _minimalMemory().copyWith(title: 'Picnic');
      expect(m.displayTitle, 'Picnic');
    });

    test('displayTitle returns empty string when both null', () {
      expect(_minimalMemory().displayTitle, '');
    });

    test('toString includes id and display title', () {
      final s = _fullMemory().toString();
      expect(s, contains('mem_full'));
      expect(s, contains('Date Night'));
    });

    test('hasContent returns true when any content field is filled', () {
      expect(_fullMemory().hasContent, true);
    });

    test('hasContent returns false for empty memory', () {
      expect(_minimalMemory().hasContent, false);
    });
  });

  // ---------------------------------------------------------------------------
  // Denormalized moment fields
  // ---------------------------------------------------------------------------

  group('Memory denormalized moment fields', () {
    test('fromJson parses momentEndDate, momentTimeSlot, momentNotes', () {
      final json = _fullMomentLinkedJson();
      final memory = Memory.fromJson('id', json);

      expect(memory.momentEndDate, isNotNull);
      expect(memory.momentTimeSlot, 'evening');
      expect(memory.momentNotes, 'Try the new Italian place');
    });

    test('new fields are null when absent (backward compat)', () {
      final json = _minimalJson();
      final memory = Memory.fromJson('id', json);

      expect(memory.momentEndDate, isNull);
      expect(memory.momentTimeSlot, isNull);
      expect(memory.momentNotes, isNull);
    });

    test('toJson includes new denormalized fields when present', () {
      final memory = _fullMemory();
      final json = memory.toJson();

      expect(json['momentEndDate'], isA<Timestamp>());
      expect(json['momentTimeSlot'], 'evening');
      expect(json['momentNotes'], 'Try the new Italian place');
    });

    test('toJson omits new fields when null', () {
      final memory = _minimalMemory();
      final json = memory.toJson();

      expect(json.containsKey('momentEndDate'), false);
      expect(json.containsKey('momentTimeSlot'), false);
      expect(json.containsKey('momentNotes'), false);
    });

    test('copyWith updates new fields', () {
      final original = _minimalMemory();
      final copy = original.copyWith(
        momentEndDate: DateTime.utc(2026, 3, 15),
        momentTimeSlot: 'morning',
        momentNotes: 'Some notes',
      );

      expect(copy.momentEndDate, DateTime.utc(2026, 3, 15));
      expect(copy.momentTimeSlot, 'morning');
      expect(copy.momentNotes, 'Some notes');
      expect(original.momentEndDate, isNull);
    });
  });
}

// =============================================================================
// Test Helpers
// =============================================================================

Map<String, dynamic> _fullMomentLinkedJson() => {
  'momentId': 'mom_456',
  'momentName': 'Date Night',
  'momentType': 'connect',
  'momentDate': Timestamp.fromDate(DateTime.utc(2026, 3, 10)),
  'momentEndDate': Timestamp.fromDate(DateTime.utc(2026, 3, 12)),
  'momentTimeSlot': 'evening',
  'momentNotes': 'Try the new Italian place',
  'createdBy': 'user_abc',
  'photoPaths': ['path/photo_0.jpg', 'path/photo_1.jpg'],
  'thumbPaths': ['path/photo_0_thumb.jpg', 'path/photo_1_thumb.jpg'],
  'caption': 'Great evening!',
  'place': 'Downtown',
  'music': 'Something by The Beatles',
  'checkinId': 'checkin_789',
  'reactions': {'user_def': '❤️'},
  'date': Timestamp.fromDate(DateTime.utc(2026, 3, 10)),
  'createdAt': Timestamp.fromDate(DateTime(2026, 3, 11)),
};

Map<String, dynamic> _standaloneJson() => {
  'createdBy': 'user_abc',
  'title': 'Surprise picnic',
  'photoPaths': <String>[],
  'thumbPaths': <String>[],
  'reactions': <String, String>{},
  'date': Timestamp.fromDate(DateTime.utc(2026, 3, 8)),
  'createdAt': Timestamp.fromDate(DateTime(2026, 3, 9)),
};

Map<String, dynamic> _minimalJson() => {
  'createdBy': 'user_abc',
  'photoPaths': <String>[],
  'thumbPaths': <String>[],
  'reactions': <String, String>{},
  'date': Timestamp.fromDate(DateTime.utc(2026, 3, 10)),
  'createdAt': Timestamp.fromDate(DateTime(2026, 3, 11)),
};

Memory _fullMemory() => Memory(
  id: 'mem_full',
  momentId: 'mom_456',
  momentName: 'Date Night',
  momentType: 'connect',
  momentDate: DateTime.utc(2026, 3, 10),
  momentEndDate: DateTime.utc(2026, 3, 12),
  momentTimeSlot: 'evening',
  momentNotes: 'Try the new Italian place',
  createdBy: 'user_abc',
  photoPaths: ['path/photo_0.jpg', 'path/photo_1.jpg'],
  thumbPaths: ['path/photo_0_thumb.jpg', 'path/photo_1_thumb.jpg'],
  caption: 'Great evening!',
  place: 'Downtown',
  music: 'Something by The Beatles',
  checkinId: 'checkin_789',
  reactions: {'user_def': '❤️'},
  date: DateTime.utc(2026, 3, 10),
  createdAt: DateTime(2026, 3, 11),
);

Memory _minimalMemory() => Memory(
  id: 'mem_min',
  createdBy: 'user_abc',
  date: DateTime.utc(2026, 3, 10),
  createdAt: DateTime(2026, 3, 11),
);
