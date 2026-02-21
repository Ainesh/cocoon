/// Unit tests for AvatarData, AvatarColor, AvatarSelection, and PredefinedAvatars.
///
/// Covers: AVA-01 through AVA-05 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/avatar_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ===========================================================================
  // AvatarData
  // ===========================================================================

  group('AvatarData', () {
    // AVA-01
    test('getAvatarKey returns correct format "id_colorName"', () {
      final avatar = createTestAvatarData(id: 'avatar_1');
      expect(avatar.getAvatarKey(AvatarColor.blue), 'avatar_1_blue');
      expect(avatar.getAvatarKey(AvatarColor.green), 'avatar_1_green');
      expect(avatar.getAvatarKey(AvatarColor.purple), 'avatar_1_purple');
      expect(avatar.getAvatarKey(AvatarColor.orange), 'avatar_1_orange');
      expect(avatar.getAvatarKey(AvatarColor.gray), 'avatar_1_gray');
    });

    test('AvatarData stores id, name, and icon', () {
      final avatar = createTestAvatarData(
        id: 'avatar_test',
        name: 'Test',
        icon: Icons.star,
      );
      expect(avatar.id, 'avatar_test');
      expect(avatar.name, 'Test');
      expect(avatar.icon, Icons.star);
    });
  });

  // ===========================================================================
  // AvatarColor Enum
  // ===========================================================================

  group('AvatarColor', () {
    // AVA-02
    test('has all expected colors', () {
      expect(AvatarColor.values.length, 5);
      expect(AvatarColor.values, contains(AvatarColor.blue));
      expect(AvatarColor.values, contains(AvatarColor.green));
      expect(AvatarColor.values, contains(AvatarColor.orange));
      expect(AvatarColor.values, contains(AvatarColor.purple));
      expect(AvatarColor.values, contains(AvatarColor.gray));
    });

    test('each color has a non-null color value and label', () {
      for (final color in AvatarColor.values) {
        expect(color.color, isNotNull);
        expect(color.label, isNotEmpty);
      }
    });
  });

  // ===========================================================================
  // AvatarSelection
  // ===========================================================================

  group('AvatarSelection', () {
    // AVA-03
    test('key returns combined avatar+color key', () {
      final selection = createTestAvatarSelection(
        avatar: createTestAvatarData(id: 'avatar_5'),
        color: AvatarColor.purple,
      );
      expect(selection.key, 'avatar_5_purple');
    });
  });

  // ===========================================================================
  // PredefinedAvatars
  // ===========================================================================

  group('PredefinedAvatars', () {
    // AVA-04
    test('all contains 12 avatars', () {
      expect(PredefinedAvatars.all.length, 12);
    });

    // AVA-05
    test('all avatar IDs are unique', () {
      final ids = PredefinedAvatars.all.map((a) => a.id).toSet();
      expect(ids.length, PredefinedAvatars.all.length);
    });

    test('all avatars have names and icons', () {
      for (final avatar in PredefinedAvatars.all) {
        expect(avatar.id, isNotEmpty);
        expect(avatar.name, isNotEmpty);
        expect(avatar.icon, isNotNull);
      }
    });
  });
}
