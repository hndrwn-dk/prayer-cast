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

  /// Ink wash on canopy. Light uses opaque mist so [glyph] stays readable.
  static Color inkWash(BuildContext context, double alpha) => isForest(context)
      ? PrayerCastColors.ink.withValues(alpha: alpha)
      : PrayerCastColors.mist;

  /// Leaf wash on canopy. Light uses opaque mistDeep so [onSurface] reads.
  static Color leafWash(BuildContext context, double alpha) => isForest(context)
      ? PrayerCastColors.leaf.withValues(alpha: alpha)
      : PrayerCastColors.mistDeep;

  /// Selected timing chip. Forest stays solid leaf; light stays mistDeep.
  static Color segmentFill(BuildContext context) =>
      isForest(context) ? PrayerCastColors.leaf : PrayerCastColors.mistDeep;

  /// Emphasis on a wash. Forest keeps surfaceRaised.
  static Color washEmphasis(BuildContext context) =>
      isForest(context) ? PrayerCastColors.surfaceRaised : onSurface(context);

  /// Label on a wash. Forest keeps mist.
  static Color washLabel(BuildContext context) =>
      isForest(context) ? PrayerCastColors.mist : glyph(context);

  /// Secondary line on a wash. Forest keeps mistDeep. Light uses [glyph]
  /// because quiet on mist is under 4.5:1.
  static Color washDetail(BuildContext context) =>
      isForest(context) ? PrayerCastColors.mistDeep : glyph(context);

  /// Dropdown and field value. Forest keeps [PrayerCastTheme.forestDropdown].
  static TextStyle fieldValue(BuildContext context) =>
      PrayerCastTheme.forestDropdown.copyWith(color: glyph(context));

  /// Dawn on both forest and light.
  static Color hairline(BuildContext context) =>
      switch (Theme.of(context).brightness) {
        Brightness.dark || Brightness.light => PrayerCastColors.dawn,
      };

  /// Icon well and round actions. Forest keeps canopy; light uses leaf
  /// so the chip sits on mist instead of a near-black forest fill.
  static Color mark(BuildContext context) =>
      isForest(context) ? PrayerCastColors.canopy : PrayerCastColors.leaf;

  /// Glyph on [mark].
  static Color onMark(BuildContext context) => isForest(context)
      ? PrayerCastColors.mist
      : PrayerCastColors.surfaceRaised;

  /// Dialog panel. Forest keeps canopyDeep; light uses the raised mist slab.
  static Color panel(BuildContext context) => isForest(context)
      ? PrayerCastColors.canopyDeep
      : PrayerCastColors.surfaceRaised;

  static Color panelTitle(BuildContext context) => isForest(context)
      ? PrayerCastColors.surfaceRaised
      : PrayerCastColors.ink;

  static Color panelBody(BuildContext context) => isForest(context)
      ? PrayerCastColors.mist
      : PrayerCastColors.inkSoft;

  /// Edge of a dialog. Forest keeps a mist stroke; light uses dawn.
  static Color panelRule(BuildContext context) => isForest(context)
      ? PrayerCastColors.mist.withValues(alpha: 0.28)
      : PrayerCastColors.dawn;

  /// Page hairline. Mist on ink in Forest; ink on mist in Light.
  static Color rule(BuildContext context) => isForest(context)
      ? PrayerCastColors.mist.withValues(alpha: 0.22)
      : PrayerCastColors.ink.withValues(alpha: 0.28);

  /// Soft dawn panel (recovery banners, accent wells). Not raw dawnSoft —
  /// that disappears on forest.
  static Color dawnWash(BuildContext context) => isForest(context)
      ? PrayerCastColors.dawn.withValues(alpha: 0.18)
      : PrayerCastColors.dawnSoft;

  /// Primary label on [dawnWash].
  static Color onDawnWash(BuildContext context) =>
      isForest(context) ? PrayerCastColors.mist : PrayerCastColors.ink;

  /// Secondary label on [dawnWash].
  static Color onDawnWashMuted(BuildContext context) => isForest(context)
      ? PrayerCastColors.mistDeep
      : PrayerCastColors.inkSoft;

  /// Spinner / icon track that stays visible on both themes.
  static Color track(BuildContext context) => isForest(context)
      ? PrayerCastColors.mist.withValues(alpha: 0.28)
      : PrayerCastColors.ink.withValues(alpha: 0.16);

  static Color scrim(BuildContext context) => PrayerCastColors.ink.withValues(
    alpha: isForest(context) ? 0.72 : 0.38,
  );

  static SystemUiOverlayStyle systemUi(BuildContext context) =>
      isForest(context)
      ? PrayerCastTheme.forestSystemUi
      : PrayerCastTheme.mistSystemUi;
}
