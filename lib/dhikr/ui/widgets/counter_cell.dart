import 'package:flutter/material.dart';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';
import 'package:prayer_cast/dhikr/ui/widgets/counter_progress.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';

/// Single dhikr counter cell: tap increments, long press or the reset
/// button resets, and a progress bar tracks count against target.
class CounterCell extends StatelessWidget {
  const CounterCell({
    super.key,
    required this.state,
    required this.arabic,
    required this.translation,
    required this.onTap,
    required this.onReset,
    required this.resetLabel,
  });

  final DhikrCounterState state;
  final String arabic;
  final String translation;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      container: true,
      label: '$translation, ${state.count} of ${state.target}',
      onLongPressHint: resetLabel,
      child: Material(
        color: PrayerCastTokens.slab(context),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onReset,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: PrayerCastTheme.displayFont,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: PrayerCastTokens.glyph(context),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    translation,
                    style: TextStyle(
                      fontFamily: PrayerCastTheme.bodyFont,
                      fontSize: 14,
                      color: PrayerCastTokens.glyphMuted(context),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${state.count}',
                            style: TextStyle(
                              fontFamily: PrayerCastTheme.displayFont,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: PrayerCastTokens.glyph(context),
                              height: 1,
                            ),
                          ),
                          Text(
                            '/${state.target}',
                            style: TextStyle(
                              fontFamily: PrayerCastTheme.bodyFont,
                              fontSize: 18,
                              color: PrayerCastTokens.glyphMuted(context),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh),
                      iconSize: 24,
                      color: PrayerCastTokens.glyph(context),
                      tooltip: resetLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: CounterProgress(progress: state.progress),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
