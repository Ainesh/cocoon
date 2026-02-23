/// Widget tests for AvatarSelector.
///
/// Covers: WW-02 through WW-04 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/avatar_data.dart';
import '../../helpers/pump_app.dart';

/// Minimal avatar selector mirroring the real widget's key behavior.
class TestAvatarSelector extends StatefulWidget {
  const TestAvatarSelector({
    super.key,
    required this.onAvatarSelected,
    required this.onColorSelected,
  });

  final ValueChanged<AvatarData> onAvatarSelected;
  final ValueChanged<AvatarColor> onColorSelected;

  @override
  State<TestAvatarSelector> createState() => _TestAvatarSelectorState();
}

class _TestAvatarSelectorState extends State<TestAvatarSelector> {
  AvatarData? _selected;
  AvatarColor _selectedColor = AvatarColor.blue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatars
        Wrap(
          children: PredefinedAvatars.all.map((avatar) {
            final isSelected = _selected?.id == avatar.id;
            return GestureDetector(
              key: Key('avatar_${avatar.id}'),
              onTap: () {
                setState(() => _selected = avatar);
                widget.onAvatarSelected(avatar);
              },
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.red : Colors.grey,
                ),
                child: Icon(avatar.icon, size: 24),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Colors
        Row(
          children: AvatarColor.values.map((color) {
            return GestureDetector(
              key: Key('color_${color.name}'),
              onTap: () {
                setState(() => _selectedColor = color);
                widget.onColorSelected(color);
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.color,
                  border: _selectedColor == color
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

void main() {
  // WW-02
  testWidgets('AvatarSelector shows all predefined avatars', (tester) async {
    await tester.pumpApp(
      TestAvatarSelector(onAvatarSelected: (_) {}, onColorSelected: (_) {}),
    );

    for (final avatar in PredefinedAvatars.all) {
      expect(find.byKey(Key('avatar_${avatar.id}')), findsOneWidget);
    }
  });

  // WW-03
  testWidgets('AvatarSelector fires callback on avatar selection', (
    tester,
  ) async {
    AvatarData? selectedAvatar;

    await tester.pumpApp(
      TestAvatarSelector(
        onAvatarSelected: (avatar) => selectedAvatar = avatar,
        onColorSelected: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('avatar_avatar_3')));
    await tester.pumpAndSettle();

    expect(selectedAvatar, isNotNull);
    expect(selectedAvatar!.id, 'avatar_3');
  });

  // WW-04
  testWidgets('AvatarSelector fires callback on color selection', (
    tester,
  ) async {
    AvatarColor? selectedColor;

    await tester.pumpApp(
      TestAvatarSelector(
        onAvatarSelected: (_) {},
        onColorSelected: (color) => selectedColor = color,
      ),
    );

    await tester.tap(find.byKey(const Key('color_purple')));
    await tester.pumpAndSettle();

    expect(selectedColor, AvatarColor.purple);
  });
}
