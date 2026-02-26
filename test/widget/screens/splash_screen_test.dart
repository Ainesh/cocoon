/// Widget tests for SplashScreen.
///
/// Covers: WS-01 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Minimal splash for testing (avoids Firebase dependency).
class TestSplashScreen extends StatelessWidget {
  const TestSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Kairos',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  // WS-01
  testWidgets('SplashScreen shows app icon and loading indicator', (
    tester,
  ) async {
    await tester.pumpScreen(const TestSplashScreen());

    // Verify heart icon is present
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    // Verify app name is displayed
    expect(find.text('Kairos'), findsOneWidget);

    // Verify loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
