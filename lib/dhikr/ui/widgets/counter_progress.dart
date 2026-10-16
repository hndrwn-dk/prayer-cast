import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';

/// Rounded progress bar for a dhikr counter (0.0 to 1.0).
class CounterProgress extends StatelessWidget {
  const CounterProgress({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: PrayerCastTokens.track(context),
        valueColor: const AlwaysStoppedAnimation<Color>(PrayerCastColors.leaf),
        minHeight: 6,
      ),
    );
  }
}
