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

  /// Card and field well. Forest keeps canopyDeep; light uses [surface]
  /// so theme ink sits on a light slab.
  static Color slab(BuildContext context) =>
      isForest(context) ? PrayerCastColors.canopyDeep : surface(context);

  /// Icon or label on a page fill or [slab]. Forest keeps mist.
  static Color glyph(BuildContext context) =>
      isForest(context) ? PrayerCastColors.mist : onSurface(context);

  /// Secondary ink on a page fill or [slab]. Forest keeps mistDeep.
  static Color glyphMuted(BuildContext context) => isForest(context)
      ? PrayerCastColors.mistDeep
      : Theme.of(context).colorScheme.onSurfaceVariant;

  /// Dropdown and field value. Forest keeps [PrayerCastTheme.forestDropdown].
  static TextStyle fieldValue(BuildContext context) =>
      PrayerCastTheme.forestDropdown.copyWith(color: glyph(context));

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
