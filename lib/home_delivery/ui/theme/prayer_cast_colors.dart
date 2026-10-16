import 'package:flutter/material.dart';

/// Brand palette — calm forest ink on misted stone (not Material seed defaults).
///
/// Roles follow 60-30-10. Hex values are fixed; themes only swap which
/// token fills each role:
///
/// | Share | Role | Forest | Light |
/// |------:|------|--------|-------|
/// | 60% | Dominant neutral (page ground) | [ink], [canopyDeep] slabs | [surface], [atmosphere], [surfaceRaised] |
/// | 30% | Primary brand (green) | [canopy], [leaf], [canopyQuiet] | [leaf], [canopyQuiet], mist greens as wash |
/// | 10% | Accent | [dawn], dawn washes | [dawn], [dawnSoft] |
///
/// Semantic alerts ([danger] / [dangerSoft]) sit outside the brand split.
abstract final class PrayerCastColors {
  // --- 60% neutrals (ground + type) ---

  /// Forest page fill. Light body ink.
  static const Color ink = Color(0xFF10261F);

  /// Soft body / secondary ink on light surfaces.
  static const Color inkSoft = Color(0xFF2A453A);

  /// Forest raised type and light status glyphs.
  static const Color mist = Color(0xFFD7E4DC);

  /// Forest muted type; light soft brand wash.
  static const Color mistDeep = Color(0xFFB7CBBF);

  /// Light page fill.
  static const Color surface = Color(0xFFF3F7F4);

  /// Light raised slab / forest on-surface type.
  static const Color surfaceRaised = Color(0xFFFAFCFA);

  /// Light hero / atmosphere plane.
  static const Color atmosphere = Color(0xFFEAF3EE);

  /// Secondary quiet label (use sparingly; prefer theme tokens for contrast).
  static const Color quiet = Color(0xFF5C6B63);

  // --- 30% primary brand (green) ---

  /// Solid brand green — Forest marks, strong fills.
  static const Color canopy = Color(0xFF0F5C45);

  /// Deep brand green — Forest slabs and panels.
  static const Color canopyDeep = Color(0xFF0A3D2E);

  /// Filled actions on a light page. Less chroma than [canopy].
  static const Color canopyQuiet = Color(0xFF3D6A58);

  /// Brighter brand green — Light marks, Forest selected chips.
  static const Color leaf = Color(0xFF2F8F6B);

  // --- 10% accent (dawn) ---

  /// Accent gold — hairlines and emphasis in both themes.
  static const Color dawn = Color(0xFFC9852A);

  /// Soft accent wash on light surfaces.
  static const Color dawnSoft = Color(0xFFF0D9B0);

  // --- Semantic (outside 60-30-10) ---

  static const Color danger = Color(0xFF9B3A2F);
  static const Color dangerSoft = Color(0xFFF0D2CC);
}
