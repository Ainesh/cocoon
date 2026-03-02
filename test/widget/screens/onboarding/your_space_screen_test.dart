/// Widget tests for YourSpaceScreen (Screen 1 — Space).
///
/// Covers: staggered entrance, input interaction, tagline flow, exit.
/// Uses pump() with specific durations to advance through entrance timers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/screens/onboarding/screens/your_space_screen.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('YourSpaceScreen', () {
    late String? continuedName;

    setUp(() => continuedName = null);

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        YourSpaceScreen(
          initialName: '',
          onContinue: (name) => continuedName = name,
        ),
      );
    }

    /// Advance past all entrance timers (600+2500+3800+1800 = 8700ms).
    Future<void> pumpPastEntrance(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 9000));
    }

    /// Drain all pending timers so the test doesn't fail with
    /// "Timer still pending" assertion.
    Future<void> drainTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 15));
    }

    testWidgets('renders title "Space" after entrance delay', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Space'), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('renders subtitle after stagger', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(milliseconds: 3200));
      expect(
        find.text(
          'Your journey starts by\ncreating a shared space\nfor your relationship',
        ),
        findsOneWidget,
      );
      await drainTimers(tester);
    });

    testWidgets('renders prompt "tap to name your space"', (tester) async {
      await pump(tester);
      await pumpPastEntrance(tester);
      expect(find.text('tap to name your space'), findsOneWidget);
    });

    testWidgets('tapping prompt reveals text field', (tester) async {
      await pump(tester);
      await pumpPastEntrance(tester);

      await tester.tap(find.text('tap to name your space'));
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('entering text and unfocusing shows tagline', (tester) async {
      await pump(tester);
      await pumpPastEntrance(tester);

      await tester.tap(find.text('tap to name your space'));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'Our Space');
      await tester.pump();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      // Wait for tagline controller (1200ms) + settle
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Your personal, intimate, and\nsafe place to express\nand build memories',
        ),
        findsOneWidget,
      );
      // Drain continue timer (2000ms)
      await tester.pump(const Duration(milliseconds: 2500));
    });

    testWidgets('tap to continue calls onContinue with name', (tester) async {
      await pump(tester);
      await pumpPastEntrance(tester);

      await tester.tap(find.text('tap to name your space'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Ours');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Wait for tagline (1200ms) + continue delay (2000ms)
      await tester.pump(const Duration(milliseconds: 3500));

      await tester.tap(find.text('tap to continue'));
      await tester.pump();

      expect(continuedName, 'Ours');
    });

    testWidgets('clearing name resets to subtitle state', (tester) async {
      await pump(tester);
      await pumpPastEntrance(tester);

      // Enter name
      await tester.tap(find.text('tap to name your space'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Test');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 1500));

      // Tap name to re-edit
      await tester.tap(find.text('Test'));
      await tester.pump();
      await tester.pump();

      // Clear text
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        find.text(
          'Your journey starts by\ncreating a shared space\nfor your relationship',
        ),
        findsOneWidget,
      );
      // Drain any remaining timers
      await drainTimers(tester);
    });
  });
}
