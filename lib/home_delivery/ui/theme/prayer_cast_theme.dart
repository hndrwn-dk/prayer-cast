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
}
