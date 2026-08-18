import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prayer_cast_colors.dart';

/// Premium, high-legibility theme for young and older users.
///
/// Display: Fraunces (expressive brand). Body: Atkinson Hyperlegible
/// (designed for maximum readability). Large minimum tap targets (56).
abstract final class PrayerCastTheme {
  static const String displayFont = 'Fraunces';
  static const String bodyFont = 'AtkinsonHyperlegible';

  /// Minimum comfortable tap height for older fingers.
  static const double minTap = 56;

  /// Card outline on forest screens. Slightly heavier than 1px hairline,
  /// still inkSoft grey — gold is reserved for focus / selection.
  static const double cardHairline = 1.35;

  /// Selected value inside forest dropdowns. Regular weight so titles
  /// (titleMedium / dawn section labels) stay the loudest type.
  static const TextStyle forestDropdown = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: PrayerCastColors.mist,
  );

  static ThemeData light() {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.5,
        color: PrayerCastColors.ink,
        fontVariations: [FontVariation('wght', 600)],
      ),
      displayMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: PrayerCastColors.ink,
        fontVariations: [FontVariation('wght', 600)],
      ),
      displaySmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: PrayerCastColors.ink,
        fontVariations: [FontVariation('wght', 600)],
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: PrayerCastColors.ink,
        fontVariations: [FontVariation('wght', 600)],
      ),
      titleLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: PrayerCastColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: PrayerCastColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PrayerCastColors.inkSoft,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PrayerCastColors.inkSoft,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: PrayerCastColors.quiet,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: PrayerCastColors.surfaceRaised,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: PrayerCastColors.inkSoft,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PrayerCastColors.surface,
      colorScheme: const ColorScheme.light(
        primary: PrayerCastColors.canopy,
        onPrimary: PrayerCastColors.surfaceRaised,
        primaryContainer: PrayerCastColors.mist,
        onPrimaryContainer: PrayerCastColors.canopyDeep,
        secondary: PrayerCastColors.dawn,
        onSecondary: PrayerCastColors.ink,
        secondaryContainer: PrayerCastColors.dawnSoft,
        onSecondaryContainer: PrayerCastColors.ink,
        error: PrayerCastColors.danger,
        onError: PrayerCastColors.surfaceRaised,
        errorContainer: PrayerCastColors.dangerSoft,
        onErrorContainer: PrayerCastColors.danger,
        surface: PrayerCastColors.surface,
        onSurface: PrayerCastColors.ink,
        onSurfaceVariant: PrayerCastColors.quiet,
        outline: PrayerCastColors.mistDeep,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PrayerCastColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: PrayerCastColors.ink,
          fontVariations: [FontVariation('wght', 600)],
        ),
        iconTheme: IconThemeData(color: PrayerCastColors.ink, size: 26),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, minTap)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: const WidgetStatePropertyAll(PrayerCastColors.canopy),
          foregroundColor:
              const WidgetStatePropertyAll(PrayerCastColors.surfaceRaised),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: const WidgetStatePropertyAll(PrayerCastColors.canopy),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PrayerCastColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          color: PrayerCastColors.surfaceRaised,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: PrayerCastColors.mistDeep,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Dark forest surfaces for Home, Speaker, and Prayer times.
  ///
  /// Every ColorScheme slot is a [PrayerCastColors] token so Material 3
  /// does not fall back to purple.
  static ThemeData forest() {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 48,
        fontWeight: FontWeight.w300,
        height: 1.05,
        letterSpacing: -0.8,
        color: PrayerCastColors.surfaceRaised,
        fontVariations: [FontVariation('wght', 300)],
      ),
      displayMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.1,
        color: PrayerCastColors.surfaceRaised,
        fontVariations: [FontVariation('wght', 500)],
      ),
      displaySmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.15,
        color: PrayerCastColors.surfaceRaised,
        fontVariations: [FontVariation('wght', 500)],
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: -0.2,
        color: PrayerCastColors.surfaceRaised,
        fontVariations: [FontVariation('wght', 500)],
      ),
      titleLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: PrayerCastColors.surfaceRaised,
        fontVariations: [FontVariation('wght', 500)],
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: PrayerCastColors.surfaceRaised,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PrayerCastColors.mist,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PrayerCastColors.mistDeep,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: PrayerCastColors.mistDeep,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: PrayerCastColors.surfaceRaised,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
        color: PrayerCastColors.mistDeep,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PrayerCastColors.ink,
      canvasColor: PrayerCastColors.canopyDeep,
      colorScheme: const ColorScheme.dark(
        primary: PrayerCastColors.leaf,
        onPrimary: PrayerCastColors.surfaceRaised,
        primaryContainer: PrayerCastColors.canopy,
        onPrimaryContainer: PrayerCastColors.mist,
        secondary: PrayerCastColors.dawn,
        onSecondary: PrayerCastColors.ink,
        secondaryContainer: PrayerCastColors.canopy,
        onSecondaryContainer: PrayerCastColors.dawnSoft,
        tertiary: PrayerCastColors.dawn,
        onTertiary: PrayerCastColors.ink,
        error: PrayerCastColors.danger,
        onError: PrayerCastColors.surfaceRaised,
        errorContainer: PrayerCastColors.dangerSoft,
        onErrorContainer: PrayerCastColors.danger,
        surface: PrayerCastColors.ink,
        onSurface: PrayerCastColors.surfaceRaised,
        onSurfaceVariant: PrayerCastColors.mistDeep,
        outline: PrayerCastColors.inkSoft,
        outlineVariant: PrayerCastColors.canopy,
        inverseSurface: PrayerCastColors.mist,
        onInverseSurface: PrayerCastColors.ink,
        inversePrimary: PrayerCastColors.canopy,
        surfaceContainerLowest: PrayerCastColors.ink,
        surfaceContainerLow: PrayerCastColors.ink,
        surfaceContainer: PrayerCastColors.canopyDeep,
        surfaceContainerHigh: PrayerCastColors.canopyDeep,
        surfaceContainerHighest: PrayerCastColors.inkSoft,
      ),
      textTheme: textTheme,
      dialogTheme: const DialogThemeData(
        backgroundColor: PrayerCastColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 1.25,
          color: PrayerCastColors.surfaceRaised,
          fontVariations: [FontVariation('wght', 500)],
        ),
        contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: PrayerCastColors.mist,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PrayerCastColors.mist,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: PrayerCastColors.surfaceRaised,
          fontVariations: [FontVariation('wght', 500)],
        ),
        iconTheme: IconThemeData(color: PrayerCastColors.mist, size: 26),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, minTap)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: const WidgetStatePropertyAll(PrayerCastColors.canopy),
          foregroundColor:
              const WidgetStatePropertyAll(PrayerCastColors.surfaceRaised),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, minTap)),
          foregroundColor: const WidgetStatePropertyAll(PrayerCastColors.mist),
          side: const WidgetStatePropertyAll(
            BorderSide(color: PrayerCastColors.inkSoft, width: 1.2),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: const WidgetStatePropertyAll(PrayerCastColors.mist),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PrayerCastColors.canopyDeep,
        labelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          color: PrayerCastColors.mistDeep,
        ),
        hintStyle: const TextStyle(
          fontFamily: bodyFont,
          color: PrayerCastColors.quiet,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PrayerCastColors.inkSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PrayerCastColors.inkSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PrayerCastColors.dawn, width: 1.4),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(PrayerCastColors.canopyDeep),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: PrayerCastColors.canopyDeep,
        textStyle: forestDropdown,
        labelTextStyle: WidgetStatePropertyAll(forestDropdown),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PrayerCastColors.canopyDeep,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          color: PrayerCastColors.surfaceRaised,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: PrayerCastColors.inkSoft,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PrayerCastColors.leaf,
        circularTrackColor: PrayerCastColors.inkSoft,
      ),
    );
  }

  static TextStyle editorialEyebrow(Color color) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4,
        height: 1.2,
        color: color,
      );

  static const TextStyle heroTime = TextStyle(
    fontFamily: displayFont,
    fontSize: 72,
    fontWeight: FontWeight.w300,
    letterSpacing: -2.4,
    height: 0.92,
    color: PrayerCastColors.surfaceRaised,
    fontVariations: [FontVariation('wght', 300)],
  );

  static InputDecoration darkField(String? label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: PrayerCastColors.canopyDeep,
      labelStyle: const TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        color: PrayerCastColors.mistDeep,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PrayerCastColors.inkSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PrayerCastColors.inkSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PrayerCastColors.dawn, width: 1.4),
      ),
    );
  }
}
