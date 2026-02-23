/// Helper to wrap widgets in a [MaterialApp] with the Cocoon theme for testing.
///
/// Usage:
/// ```dart
/// await tester.pumpApp(MyWidget());
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/theme/app_colors.dart';

/// Extension on [WidgetTester] to pump widgets with the app theme.
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped in [MaterialApp] with the Cocoon dark theme.
  Future<void> pumpApp(
    Widget widget, {
    NavigatorObserver? navigatorObserver,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: AppColors.refinedRed,
            onPrimary: AppColors.pureBlack,
            secondary: AppColors.accentPurple,
            surface: AppColors.darkGlass,
            onSurface: AppColors.lightText,
            onSurfaceVariant: AppColors.subtleText,
            error: AppColors.error,
          ),
          scaffoldBackgroundColor: AppColors.pureBlack,
          brightness: Brightness.dark,
        ),
        navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
        home: Scaffold(body: widget),
      ),
    );
  }

  /// Pumps a widget wrapped in [MaterialApp] using a [Scaffold] as home,
  /// useful for testing screens directly.
  Future<void> pumpScreen(Widget screen) async {
    await pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: AppColors.refinedRed,
            surface: AppColors.darkGlass,
            onSurface: AppColors.lightText,
            error: AppColors.error,
          ),
          scaffoldBackgroundColor: AppColors.pureBlack,
          brightness: Brightness.dark,
        ),
        home: screen,
      ),
    );
  }
}
