/// Cocoon - Grow together, intentionally.
///
/// A nurturing space for relationship transformation.
/// Private. Intentional. Transformative.
///
/// ## Architecture
///
/// ```
/// lib/
/// ├── main.dart           # App entry point and theme
/// ├── models/             # Data models (Moment, UserCheckIn, etc.)
/// ├── services/           # Business logic (auth, firestore)
/// ├── screens/            # UI screens organized by feature
/// │   ├── dashboard/      # Main dashboard with health card
/// │   └── checkin/        # Check-in flow
/// ├── widgets/            # Reusable UI components
/// ├── router/             # GoRouter configuration
/// └── theme/              # Colors, typography, spacing
/// ```
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';

/// Application entry point.
///
/// Initializes Firebase, notifications, locks orientation to portrait, and launches the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode only for optimal layout
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications (non-blocking)
  _initializeNotifications();

  runApp(const CocoonApp());
}

/// Initialize push notifications.
///
/// This is done asynchronously to not block app startup.
/// Token registration with Firestore happens after user login.
Future<void> _initializeNotifications() async {
  try {
    final token = await NotificationService.instance.initialize();
    if (token != null) {
      debugPrint(
        'Notifications initialized with token: ${token.substring(0, 20)}...',
      );
    } else {
      debugPrint('Notifications not available (permission denied or error)');
    }
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }
}

/// Root widget of the Cocoon application.
///
/// Features a dark neumorphic theme with:
/// - Warm red primary accent ([AppColors.refinedRed])
/// - Soft purple secondary ([AppColors.accentPurple])
/// - Pure black background ([AppColors.pureBlack])
class CocoonApp extends StatelessWidget {
  const CocoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cocoon',
      debugShowCheckedModeBanner: false,
      theme: _buildCocoonTheme(),
      routerConfig: AppRouter.router,
    );
  }

  /// Builds the Cocoon dark neumorphic theme.
  ///
  /// Uses Material 3 with custom color scheme derived from [AppColors].
  ThemeData _buildCocoonTheme() {
    // Build color scheme from centralized AppColors
    final colorScheme = ColorScheme.dark(
      primary: AppColors.refinedRed,
      onPrimary: AppColors.pureBlack,
      primaryContainer: AppColors.refinedRed.withValues(alpha: 0.15),
      onPrimaryContainer: AppColors.brightRed,
      secondary: AppColors.accentPurple,
      onSecondary: AppColors.lightText,
      secondaryContainer: AppColors.accentPurple.withValues(alpha: 0.15),
      onSecondaryContainer: AppColors.softViolet,
      tertiary: AppColors.brightRed,
      surface: AppColors.darkGlass,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.subtleText,
      surfaceContainerLowest: AppColors.pureBlack,
      surfaceContainerLow: const Color(0xFF141414),
      surfaceContainer: AppColors.darkGlass,
      surfaceContainerHigh: AppColors.cardSurface,
      surfaceContainerHighest: const Color(0xFF2E2E2E),
      outline: AppColors.refinedRed.withValues(alpha: 0.3),
      outlineVariant: const Color(0xFF3A3A3A),
      error: AppColors.error,
      onError: AppColors.pureBlack,
    );

    // Typography styles
    final headlineStyle = GoogleFonts.outfit(color: AppColors.lightText);
    final bodyStyle = GoogleFonts.inter(color: AppColors.subtleText);
    final taglineStyle = GoogleFonts.cormorantGaramond(
      color: AppColors.subtleText,
    );

    final textTheme = TextTheme(
      // Headlines - Bold condensed (Outfit)
      displayLarge: headlineStyle.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      displayMedium: headlineStyle.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      displaySmall: headlineStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: headlineStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      headlineMedium: headlineStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: AppColors.subtleText,
      ),
      headlineSmall: headlineStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.lightText,
      ),
      // Titles (Inter)
      titleLarge: bodyStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      titleMedium: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      titleSmall: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleText,
      ),
      // Body - Clean readable (Inter)
      bodyLarge: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.dimText,
      ),
      // Labels
      labelLarge: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      labelMedium: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.subtleText,
      ),
      labelSmall: taglineStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.subtleText,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.pureBlack,
      brightness: Brightness.dark,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.pureBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.refinedRed),
        titleTextStyle: headlineStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkGlass,
        indicatorColor: AppColors.refinedRed.withValues(alpha: 0.15),
        elevation: 0,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.refinedRed, size: 26);
          }
          return const IconThemeData(color: AppColors.dimText, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return bodyStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.refinedRed,
            );
          }
          return bodyStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.dimText,
          );
        }),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(AppColors.refinedRed, 2),
        errorBorder: _inputBorder(colorScheme.error, 1),
        focusedErrorBorder: _inputBorder(colorScheme.error, 2),
        labelStyle: bodyStyle.copyWith(
          color: AppColors.dimText,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: bodyStyle.copyWith(
          color: AppColors.dimText.withValues(alpha: 0.6),
        ),
        prefixIconColor: AppColors.dimText,
        suffixIconColor: AppColors.dimText,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle()),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle().copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(AppColors.refinedRed),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: AppColors.refinedRed.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.refinedRed,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: bodyStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.refinedRed,
        foregroundColor: AppColors.pureBlack,
        elevation: 8,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: bodyStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.pureBlack,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: AppColors.refinedRed.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.08)),
        ),
        color: AppColors.darkGlass,
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.refinedRed,
        inactiveTrackColor: AppColors.refinedRed.withValues(alpha: 0.2),
        thumbColor: AppColors.refinedRed,
        overlayColor: AppColors.refinedRed.withValues(alpha: 0.15),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // Segmented Button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return AppColors.refinedRed.withValues(alpha: 0.15);
            return AppColors.darkGlass;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return AppColors.refinedRed;
            return AppColors.subtleText;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.2)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          textStyle: WidgetStatePropertyAll(
            bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardSurface,
        contentTextStyle: bodyStyle.copyWith(
          fontSize: 14,
          color: AppColors.lightText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.2)),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkGlass,
        elevation: 12,
        shadowColor: AppColors.refinedRed.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.15)),
        ),
        titleTextStyle: headlineStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        contentTextStyle: bodyStyle.copyWith(
          fontSize: 16,
          color: AppColors.subtleText,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkGlass,
        elevation: 12,
        shadowColor: AppColors.refinedRed.withValues(alpha: 0.15),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: AppColors.refinedRed.withValues(alpha: 0.4),
        dragHandleSize: const Size(40, 4),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: AppColors.refinedRed.withValues(alpha: 0.1),
        thickness: 1,
      ),

      // Progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.refinedRed,
        linearTrackColor: AppColors.refinedRed.withValues(alpha: 0.15),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkGlass,
        selectedColor: AppColors.refinedRed.withValues(alpha: 0.15),
        side: BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: bodyStyle.copyWith(
          fontSize: 14,
          color: AppColors.lightText,
        ),
        elevation: 0,
      ),

      // Date Picker
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.darkGlass,
        headerBackgroundColor: AppColors.refinedRed.withValues(alpha: 0.15),
        headerForegroundColor: AppColors.lightText,
        dayStyle: bodyStyle,
        yearStyle: bodyStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Time Picker
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.darkGlass,
        hourMinuteColor: AppColors.darkSurface,
        dayPeriodColor: AppColors.refinedRed.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Icons
      iconTheme: const IconThemeData(color: AppColors.subtleText, size: 24),

      // List Tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: bodyStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        subtitleTextStyle: bodyStyle.copyWith(
          fontSize: 14,
          color: AppColors.subtleText,
        ),
        tileColor: Colors.transparent,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.refinedRed;
          return AppColors.dimText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.refinedRed.withValues(alpha: 0.3);
          return AppColors.cardSurface;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.refinedRed;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.pureBlack),
        side: BorderSide(
          color: AppColors.refinedRed.withValues(alpha: 0.5),
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.refinedRed;
          return AppColors.dimText;
        }),
      ),
    );
  }

  /// Creates an input border with optional color and width.
  OutlineInputBorder _inputBorder([Color? color, double width = 0]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: color != null
          ? BorderSide(color: color, width: width)
          : BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.1)),
    );
  }

  /// Creates a standard button style with neumorphic appearance.
  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(4),
      shadowColor: WidgetStatePropertyAll(
        AppColors.refinedRed.withValues(alpha: 0.25),
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: const WidgetStatePropertyAll(AppColors.refinedRed),
      foregroundColor: const WidgetStatePropertyAll(AppColors.pureBlack),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
