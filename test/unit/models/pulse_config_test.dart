/// Unit tests for PulseConfig model.
///
/// Covers: weight computation with overlaps, active attribute set,
/// validation, default config, single-user config, and serialisation.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/pulse_config.dart';

void main() {
  // ===========================================================================
  // Weight computation
  // ===========================================================================

  group('PulseConfig — weight computation', () {
    test('all overlap: both users pick same 3 -> equal weight', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['connection', 'intimacy', 'peace'],
          'u2': ['connection', 'intimacy', 'peace'],
        },
      );

      final w = config.weights;
      expect(w.length, 3);
      // Each attribute picked twice: raw=2, total=6, weight=2/6=1/3
      expect(w['connection'], closeTo(1 / 3, 0.01));
      expect(w['intimacy'], closeTo(1 / 3, 0.01));
      expect(w['peace'], closeTo(1 / 3, 0.01));
    });

    test('partial overlap: 2 shared + 1 unique each -> 4 attrs', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'communication'],
          'u2': ['connection', 'intimacy', 'trust'],
        },
      );

      final w = config.weights;
      expect(w.length, 4);
      // connection: 2x, trust: 2x, communication: 1x, intimacy: 1x -> total 6
      expect(w['connection'], closeTo(2 / 6, 0.01));
      expect(w['trust'], closeTo(2 / 6, 0.01));
      expect(w['communication'], closeTo(1 / 6, 0.01));
      expect(w['intimacy'], closeTo(1 / 6, 0.01));
    });

    test('minimal overlap: 1 shared + 2 unique each -> 5 attrs', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'communication'],
          'u2': ['connection', 'intimacy', 'peace'],
        },
      );

      final w = config.weights;
      expect(w.length, 5);
      // connection: 2x, rest: 1x each -> total 2+1+1+1+1 = 6
      expect(w['connection'], closeTo(2 / 6, 0.01));
      expect(w['trust'], closeTo(1 / 6, 0.01));
      expect(w['communication'], closeTo(1 / 6, 0.01));
      expect(w['intimacy'], closeTo(1 / 6, 0.01));
      expect(w['peace'], closeTo(1 / 6, 0.01));
    });

    test('weights sum to 1.0', () {
      final configs = [
        PulseConfig(
          userPicks: {
            'u1': ['connection'],
            'u2': ['connection'],
          },
        ),
        PulseConfig(
          userPicks: {
            'u1': ['connection', 'trust', 'communication'],
            'u2': ['connection', 'intimacy', 'trust'],
          },
        ),
        PulseConfig(
          userPicks: {
            'u1': ['connection', 'trust', 'communication'],
            'u2': ['connection', 'intimacy', 'peace'],
          },
        ),
      ];

      for (final config in configs) {
        final total = config.weights.values.fold(0.0, (s, v) => s + v);
        expect(total, closeTo(1.0, 0.01));
      }
    });

    test('empty picks -> empty weights', () {
      final config = PulseConfig(userPicks: {});
      expect(config.weights, isEmpty);
    });
  });

  // ===========================================================================
  // Active attributes
  // ===========================================================================

  group('PulseConfig — active attributes', () {
    test('active set is union of both users picks', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'communication'],
          'u2': ['connection', 'intimacy', 'trust'],
        },
      );

      final active = config.activeAttributes;
      expect(
        active,
        containsAll(['connection', 'trust', 'communication', 'intimacy']),
      );
      expect(active.length, 4);
    });

    test('active set preserves canonical enum order', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['communication', 'connection', 'peace'],
        },
      );

      final active = config.activeAttributes;
      // Should be in PulseAttribute enum order: connection, peace, communication
      expect(active.indexOf('connection'), lessThan(active.indexOf('peace')));
      expect(
        active.indexOf('peace'),
        lessThan(active.indexOf('communication')),
      );
    });
  });

  // ===========================================================================
  // Validation
  // ===========================================================================

  group('PulseConfig — validation', () {
    test('valid picks: 1-3 valid attribute IDs', () {
      expect(PulseConfig.isValidUserPicks(['connection']), isTrue);
      expect(PulseConfig.isValidUserPicks(['connection', 'trust']), isTrue);
      expect(
        PulseConfig.isValidUserPicks(['connection', 'trust', 'peace']),
        isTrue,
      );
    });

    test('reject empty picks', () {
      expect(PulseConfig.isValidUserPicks([]), isFalse);
    });

    test('reject more than 3 picks', () {
      expect(
        PulseConfig.isValidUserPicks([
          'connection',
          'trust',
          'peace',
          'intimacy',
        ]),
        isFalse,
      );
    });

    test('reject invalid attribute IDs', () {
      expect(PulseConfig.isValidUserPicks(['connection', 'invalid']), isFalse);
    });

    test('reject duplicate picks', () {
      expect(
        PulseConfig.isValidUserPicks(['connection', 'connection', 'trust']),
        isFalse,
      );
    });
  });

  // ===========================================================================
  // Defaults
  // ===========================================================================

  group('PulseConfig — defaults', () {
    test('default config has connection/intimacy/peace', () {
      final config = PulseConfig.defaultConfig(memberIds: ['u1', 'u2']);
      final active = config.activeAttributes;

      expect(active, containsAll(['connection', 'intimacy', 'peace']));
      expect(active.length, 3);
    });

    test('default config with no members -> empty picks but valid', () {
      final config = PulseConfig.defaultConfig();
      expect(config.userPicks, isEmpty);
      expect(config.activeAttributes, isEmpty);
    });

    test('single user -> their 3 picks with equal weight', () {
      final config = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'peace'],
        },
      );

      final w = config.weights;
      expect(w.length, 3);
      // All 1x: total 3, each 1/3
      expect(w['connection'], closeTo(1 / 3, 0.01));
      expect(w['trust'], closeTo(1 / 3, 0.01));
      expect(w['peace'], closeTo(1 / 3, 0.01));
    });
  });

  // ===========================================================================
  // Serialisation
  // ===========================================================================

  group('PulseConfig — serialisation', () {
    test('toJson / fromJson round-trip', () {
      final original = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'communication'],
          'u2': ['connection', 'intimacy', 'trust'],
        },
        updatedAt: DateTime(2026, 2, 20),
      );

      final json = original.toJson();
      final restored = PulseConfig.fromJson(json);

      expect(restored.userPicks, original.userPicks);
      expect(restored.activeAttributes, original.activeAttributes);
      expect(restored.weights.keys, original.weights.keys);
    });

    test('copyWithUserPicks updates only the specified user', () {
      final original = PulseConfig(
        userPicks: {
          'u1': ['connection', 'trust', 'communication'],
          'u2': ['connection', 'intimacy', 'trust'],
        },
      );

      final updated = original.copyWithUserPicks('u1', [
        'peace',
        'trust',
        'intimacy',
      ]);

      expect(updated.userPicks['u1'], ['peace', 'trust', 'intimacy']);
      expect(updated.userPicks['u2'], original.userPicks['u2']);
    });
  });

  // ===========================================================================
  // PulseAttribute enum
  // ===========================================================================

  group('PulseAttribute', () {
    test('fromId returns correct enum value', () {
      expect(PulseAttribute.fromId('connection'), PulseAttribute.connection);
      expect(PulseAttribute.fromId('trust'), PulseAttribute.trust);
      expect(PulseAttribute.fromId('invalid'), isNull);
    });

    test('all 8 attributes have unique IDs', () {
      final ids = PulseAttribute.values.map((a) => a.id).toSet();
      expect(ids.length, 8);
    });
  });
}
