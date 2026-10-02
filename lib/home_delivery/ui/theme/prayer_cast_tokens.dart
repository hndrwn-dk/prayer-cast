import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prayer_cast_colors.dart';
import 'prayer_cast_theme.dart';

/// Brightness-aware surfaces so every screen follows MaterialApp.
///
/// Forest is dark brightness: ink fill, raised type, light status icons.
/// Light is mist: stone fill, ink type, dark status icons. Dawn hairlines
/// stay dawn in both.
abstract final class PrayerCastTokens {
  static bool isForest(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isForest(context) ? PrayerCastColors.ink : PrayerCastColors.surface;

  static Color onSurface(BuildContext context) =>
      isForest(context) ? PrayerCastColors.surfaceRaised : PrayerCastColors.ink;

  /// Dawn on both forest and light.
  static Color hairline(BuildContext context) =>
      switch (Theme.of(context).brightness) {
        Brightness.dark || Brightness.light => PrayerCastColors.dawn,
      };

  static SystemUiOverlayStyle systemUi(BuildContext context) =>
      isForest(context)
      ? PrayerCastTheme.forestSystemUi
      : PrayerCastTheme.mistSystemUi;
}
