/// Widget tests for MomentTypeIcon functions.
///
/// Covers: WW-06 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/moment.dart';
import 'package:couple_space/widgets/moment_type_icon.dart';

void main() {
  // WW-06
  group('getMomentTypeIcon', () {
    test('returns correct icon for each MomentType', () {
      expect(
        getMomentTypeIcon(MomentType.celebrate),
        Icons.auto_awesome_rounded,
      );
      expect(
        getMomentTypeIcon(MomentType.connect),
        Icons.power_rounded,
      );
      expect(
        getMomentTypeIcon(MomentType.escape),
        Icons.flight_rounded,
      );
    });
  });

  group('getMomentTypeIconWidget', () {
    testWidgets('returns Icon widget for celebrate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: getMomentTypeIconWidget(MomentType.celebrate),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('returns Icon widget for escape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: getMomentTypeIconWidget(MomentType.escape),
          ),
        ),
      );

      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
    });
  });
}
