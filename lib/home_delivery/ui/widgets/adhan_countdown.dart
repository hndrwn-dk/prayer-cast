import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Remaining time until the next adhan, as a clock string.
final class AdhanCountdown {
  /// `MM:SS` under one hour, `H:MM:SS` otherwise. Negative is `00:00`.
  static String clock(Duration remaining) {
    final d = remaining.isNegative ? Duration.zero : remaining;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  static bool isDue(Duration remaining) => remaining <= Duration.zero;
}

/// Live "in 52:18" line under the next-adhan hero time.
class AdhanCountdownLabel extends StatefulWidget {
  const AdhanCountdownLabel({
    super.key,
    required this.scheduledAt,
    this.now,
  });

  final DateTime scheduledAt;
  final DateTime Function()? now;

  static const ValueKey<String> keyName = ValueKey<String>(
    'home_adhan_countdown',
  );

  @override
  State<AdhanCountdownLabel> createState() => _AdhanCountdownLabelState();
}

class _AdhanCountdownLabelState extends State<AdhanCountdownLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now?.call() ?? DateTime.now();
    final remaining = widget.scheduledAt.difference(now);
    final l10n = context.l10n;
    final text = AdhanCountdown.isDue(remaining)
        ? l10n.adhanCountdownNow
        : l10n.adhanCountdownIn(AdhanCountdown.clock(remaining));
    return Text(
      text,
      key: AdhanCountdownLabel.keyName,
      style: const TextStyle(
        fontFamily: PrayerCastTheme.bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: PrayerCastColors.mist,
      ),
    );
  }
}
