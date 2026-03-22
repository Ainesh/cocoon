import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/user_checkin.dart';
import 'package:couple_space/scoring/score_models.dart';
import 'package:couple_space/screens/dashboard/widgets/personal_trend_card.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('PersonalTrendCard', () {
    testWidgets('shows header text', (tester) async {
      await tester.pumpApp(
        PersonalTrendCard(
          checkIns: const [],
          streak: 0,
          onTap: () {},
        ),
      );

      expect(find.text('YOUR PULSE'), findsOneWidget);
    });

    testWidgets('shows empty state when no check-ins', (tester) async {
      await tester.pumpApp(
        PersonalTrendCard(
          checkIns: const [],
          streak: 0,
          onTap: () {},
        ),
      );

      expect(find.text('Check in to see your trend'), findsOneWidget);
    });

    testWidgets('shows invite copy', (tester) async {
      await tester.pumpApp(
        PersonalTrendCard(
          checkIns: const [],
          streak: 0,
          onTap: () {},
        ),
      );

      expect(
        find.text('Invite your partner to see\nyour shared health score'),
        findsOneWidget,
      );
    });

    testWidgets('renders chart when check-ins provided', (tester) async {
      final checkIns = [
        UserCheckIn(
          id: 'ci1',
          userId: 'u1',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          scores: const {'connection': 80, 'trust': 70},
          configSnapshot: const ConfigSnapshot(
            activeAttributes: ['connection', 'trust'],
            weights: {'connection': 0.5, 'trust': 0.5},
          ),
        ),
        UserCheckIn(
          id: 'ci2',
          userId: 'u1',
          timestamp: DateTime.now(),
          scores: const {'connection': 85, 'trust': 75},
          configSnapshot: const ConfigSnapshot(
            activeAttributes: ['connection', 'trust'],
            weights: {'connection': 0.5, 'trust': 0.5},
          ),
        ),
      ];

      await tester.pumpApp(
        PersonalTrendCard(
          checkIns: checkIns,
          streak: 2,
          onTap: () {},
        ),
      );

      expect(find.text('Check in to see your trend'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpApp(
        PersonalTrendCard(
          checkIns: const [],
          streak: 0,
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(PersonalTrendCard));
      expect(tapped, isTrue);
    });
  });
}
