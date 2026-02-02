/// Cocoon - Grow together, intentionally.
///
/// A nurturing space for relationship transformation.
/// Private. Intentional. Transformative.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';

/// Application entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CocoonApp());
}

/// Root widget of the Cocoon application.
///
/// Features a dark neumorphic theme with warm silk/amber accent
/// and soft transformation purple secondary.
class CocoonApp extends StatelessWidget {
  const CocoonApp({super.key});

  // ---------------------------------------------------------------------------
  // Cocoon Color Palette
  // ---------------------------------------------------------------------------
  
  // Backgrounds - Dark neumorphic
  static const pureBlack = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF121212);
  static const darkGlass = Color(0xFF1A1A1A);
  static const cardSurface = Color(0xFF242424);
  
  // Primary - Refined red (theme color)
  static const refinedRed = Color(0xFFFF4444);
  static const brightRed = Color(0xFFFF5555);
  static const deepRed = Color(0xFFE63939);
  
  // Secondary - Soft purple accent
  static const accentPurple = Color(0xFF8A2BE2);
  static const softViolet = Color(0xFFA855F7);
  
  // Text
  static const lightText = Color(0xFFF5F5F5);
  static const subtleText = Color(0xFFB8B8B8);
  static const dimText = Color(0xFF707070);

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
  ThemeData _buildCocoonTheme() {
    final colorScheme = ColorScheme.dark(
      primary: refinedRed,
      onPrimary: pureBlack,
      primaryContainer: refinedRed.withValues(alpha: 0.15),
      onPrimaryContainer: brightRed,
      secondary: accentPurple,
      onSecondary: lightText,
      secondaryContainer: accentPurple.withValues(alpha: 0.15),
      onSecondaryContainer: softViolet,
      tertiary: brightRed,
      surface: darkGlass,
      onSurface: lightText,
      onSurfaceVariant: subtleText,
      surfaceContainerLowest: pureBlack,
      surfaceContainerLow: const Color(0xFF141414),
      surfaceContainer: darkGlass,
      surfaceContainerHigh: cardSurface,
      surfaceContainerHighest: const Color(0xFF2E2E2E),
      outline: refinedRed.withValues(alpha: 0.3),
      outlineVariant: const Color(0xFF3A3A3A),
      error: const Color(0xFFFF6B6B),
      onError: pureBlack,
    );

    // Headlines: Modern geometric - Outfit
    final headlineStyle = GoogleFonts.outfit(color: lightText);
    
    // Body: Clean sans-serif - Inter
    final bodyStyle = GoogleFonts.inter(color: subtleText);
    
    // Tagline: Elegant - Cormorant Garamond
    final taglineStyle = GoogleFonts.cormorantGaramond(color: subtleText);

    final textTheme = TextTheme(
      // Headlines - Bold condensed
      displayLarge: headlineStyle.copyWith(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -1),
      displayMedium: headlineStyle.copyWith(fontSize: 44, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      displaySmall: headlineStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w600),
      headlineLarge: headlineStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: lightText),
      headlineMedium: headlineStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w500, color: subtleText),
      headlineSmall: headlineStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w500, color: lightText),
      // Titles
      titleLarge: bodyStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: lightText),
      titleMedium: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: lightText),
      titleSmall: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: subtleText),
      // Body - Clean readable
      bodyLarge: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      bodyMedium: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: dimText),
      // Labels
      labelLarge: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: lightText),
      labelMedium: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: subtleText),
      labelSmall: taglineStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic, color: subtleText),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: pureBlack,
      brightness: Brightness.dark,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: pureBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: refinedRed),
        titleTextStyle: headlineStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w500, color: lightText),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkGlass,
        indicatorColor: refinedRed.withValues(alpha: 0.15),
        elevation: 0,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: refinedRed, size: 26);
}
          return const IconThemeData(color: dimText, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: refinedRed);
          }
          return bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: dimText);
        }),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(refinedRed, 2),
        errorBorder: _inputBorder(colorScheme.error, 1),
        focusedErrorBorder: _inputBorder(colorScheme.error, 2),
        labelStyle: bodyStyle.copyWith(color: dimText, fontWeight: FontWeight.w500),
        hintStyle: bodyStyle.copyWith(color: dimText.withValues(alpha: 0.6)),
        prefixIconColor: dimText,
        suffixIconColor: dimText,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle()),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle().copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(refinedRed),
          side: WidgetStatePropertyAll(BorderSide(color: refinedRed.withValues(alpha: 0.5), width: 1.5)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: refinedRed,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: refinedRed,
        foregroundColor: pureBlack,
        elevation: 8,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: pureBlack),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: refinedRed.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: refinedRed.withValues(alpha: 0.08)),
        ),
        color: darkGlass,
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: refinedRed,
        inactiveTrackColor: refinedRed.withValues(alpha: 0.2),
        thumbColor: refinedRed,
        overlayColor: refinedRed.withValues(alpha: 0.15),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // Segmented Button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return refinedRed.withValues(alpha: 0.15);
            return darkGlass;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return refinedRed;
            return subtleText;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: refinedRed.withValues(alpha: 0.2))),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          textStyle: WidgetStatePropertyAll(bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardSurface,
        contentTextStyle: bodyStyle.copyWith(fontSize: 14, color: lightText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: refinedRed.withValues(alpha: 0.2)),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: darkGlass,
        elevation: 12,
        shadowColor: refinedRed.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: refinedRed.withValues(alpha: 0.15)),
        ),
        titleTextStyle: headlineStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: lightText),
        contentTextStyle: bodyStyle.copyWith(fontSize: 16, color: subtleText),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkGlass,
        elevation: 12,
        shadowColor: refinedRed.withValues(alpha: 0.15),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        dragHandleColor: refinedRed.withValues(alpha: 0.4),
        dragHandleSize: const Size(40, 4),
      ),

      // Dividers
      dividerTheme: DividerThemeData(color: refinedRed.withValues(alpha: 0.1), thickness: 1),

      // Progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: refinedRed,
        linearTrackColor: refinedRed.withValues(alpha: 0.15),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: darkGlass,
        selectedColor: refinedRed.withValues(alpha: 0.15),
        side: BorderSide(color: refinedRed.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: bodyStyle.copyWith(fontSize: 14, color: lightText),
        elevation: 0,
      ),

      // Date Picker
      datePickerTheme: DatePickerThemeData(
        backgroundColor: darkGlass,
        headerBackgroundColor: refinedRed.withValues(alpha: 0.15),
        headerForegroundColor: lightText,
        dayStyle: bodyStyle,
        yearStyle: bodyStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Time Picker
      timePickerTheme: TimePickerThemeData(
        backgroundColor: darkGlass,
        hourMinuteColor: darkSurface,
        dayPeriodColor: refinedRed.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Icons
      iconTheme: const IconThemeData(color: subtleText, size: 24),

      // List Tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: lightText),
        subtitleTextStyle: bodyStyle.copyWith(fontSize: 14, color: subtleText),
        tileColor: Colors.transparent,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return refinedRed;
          return dimText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return refinedRed.withValues(alpha: 0.3);
          return cardSurface;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return refinedRed;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(pureBlack),
        side: BorderSide(color: refinedRed.withValues(alpha: 0.5), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return refinedRed;
          return dimText;
        }),
      ),
    );
  }

  OutlineInputBorder _inputBorder([Color? color, double width = 0]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: color != null
          ? BorderSide(color: color, width: width)
          : BorderSide(color: refinedRed.withValues(alpha: 0.1)),
    );
  }

  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(4),
      shadowColor: WidgetStatePropertyAll(refinedRed.withValues(alpha: 0.25)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: const WidgetStatePropertyAll(refinedRed),
      foregroundColor: const WidgetStatePropertyAll(pureBlack),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------------------------------------------------------------
// Exported Theme Colors for use across the app
// ---------------------------------------------------------------------------

class CocoonColors {
  CocoonColors._();
  
  // Backgrounds
  static const pureBlack = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF121212);
  static const darkGlass = Color(0xFF1A1A1A);
  static const cardSurface = Color(0xFF242424);
  
  // Primary - Refined red (theme color)
  static const refinedRed = Color(0xFFFF4444);
  static const brightRed = Color(0xFFFF5555);
  static const deepRed = Color(0xFFE63939);
  
  // Secondary - Purple accent
  static const accentPurple = Color(0xFF8A2BE2);
  static const softViolet = Color(0xFFA855F7);
  
  // Text
  static const lightText = Color(0xFFF5F5F5);
  static const subtleText = Color(0xFFB8B8B8);
  static const dimText = Color(0xFF707070);
}
