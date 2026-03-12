/// Widget tests for TheWordScreen (Screen 0 — Kairos Splash).
///
/// Covers: logo, subtitle, tap-to-continue text, tap interaction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/screens/onboarding/screens/the_word_screen.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('TheWordScreen', () {
    late bool tapped;

    setUp(() => tapped = false);

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(TheWordScreen(onTap: () => tapped = true));
    }

    testWidgets('renders logo text "Kairos"', (tester) async {
      await pump(tester);
      expect(find.text('Kairos'), findsOneWidget);
    });

    testWidgets('renders subtitle "This is the moment"', (tester) async {
      await pump(tester);
      expect(find.text('This is the moment'), findsOneWidget);
    });

    testWidgets('renders "tap to continue" advance text', (tester) async {
      await pump(tester);
      expect(find.text('tap to continue'), findsOneWidget);
    });

    testWidgets('tap fires onTap callback once', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(TheWordScreen));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('second tap does not fire onTap again', (tester) async {
      var tapCount = 0;
      await tester.pumpApp(TheWordScreen(onTap: () => tapCount++));

      await tester.tap(find.byType(TheWordScreen));
      await tester.pump();
      await tester.tap(find.byType(TheWordScreen));
      await tester.pump();

      expect(tapCount, 1);
    });
  });
}
