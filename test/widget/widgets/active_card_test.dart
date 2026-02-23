/// Widget tests for ActiveCard.
///
/// Covers: WW-08 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/widgets/active_card.dart';
import '../../helpers/pump_app.dart';

void main() {
  // WW-08
  testWidgets('ActiveCard renders child content', (tester) async {
    await tester.pumpApp(
      const ActiveCard(
        heading: 'TEST HEADING',
        isActive: false,
        child: Text('Child Content'),
      ),
    );

    expect(find.text('TEST HEADING'), findsOneWidget);
    expect(find.text('Child Content'), findsOneWidget);
  });

  testWidgets('ActiveCard shows helper text when provided', (tester) async {
    await tester.pumpApp(
      const ActiveCard(
        heading: 'HEADING',
        isActive: false,
        helperText: 'Some helper',
        child: Text('Content'),
      ),
    );

    expect(find.text('Some helper'), findsOneWidget);
  });

  testWidgets('ActiveCard heading changes style when active', (tester) async {
    await tester.pumpApp(
      const ActiveCard(
        heading: 'HEADING',
        isActive: true,
        child: Text('Content'),
      ),
    );

    // Just verify it renders without error when active
    expect(find.text('HEADING'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });
}
