import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Remaining time until the next adhan, aligned to prayer-time minutes.
final class AdhanCountdown {
  /// Prayer times are HH:MM. Drop seconds so 18:41:36 until 18:58 is 17 min.
  static DateTime atMinute(DateTime time) {
    final local = time.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  static Duration remaining(DateTime scheduledAt, DateTime now) {
    return atMinute(scheduledAt).difference(atMinute(now));
  }

  /// `17 min`, `1 hr`, or `2 hr 5 min`. Negative is `0 min`.
  static String durationLabel(Duration remaining, AppLocalizations l10n) {
    final totalMinutes = remaining.isNegative ? 0 : remaining.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return l10n.adhanCountdownHoursMinutes(hours, minutes);
    }
    if (hours > 0) return l10n.adhanCountdownHours(hours);
    return l10n.adhanCountdownMinutes(minutes);
  }

  static bool isDue(Duration remaining) => remaining <= Duration.zero;
}

/// Live "Dhuhr in 52 min" line under the next-adhan hero time.
class AdhanCountdownLabel extends StatefulWidget {
  const AdhanCountdownLabel({
    super.key,
    required this.scheduledAt,
    this.prayerName,
    this.now,
  });

  final DateTime scheduledAt;
  final String? prayerName;
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
    final remaining = AdhanCountdown.remaining(widget.scheduledAt, now);
    final l10n = context.l10n;
    final countdown = AdhanCountdown.isDue(remaining)
        ? l10n.adhanCountdownNow
        : l10n.adhanCountdownIn(AdhanCountdown.durationLabel(remaining, l10n));
    final name = widget.prayerName?.trim();
    return Text.rich(
      TextSpan(
        children: [
          if (name != null && name.isNotEmpty)
            TextSpan(
              text: name,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.displayFont,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
                color: PrayerCastColors.mist,
              ),
            ),
          TextSpan(
            text: name != null && name.isNotEmpty ? ' $countdown' : countdown,
            style: const TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
              color: PrayerCastColors.mist,
            ),
          ),
        ],
      ),
      key: AdhanCountdownLabel.keyName,
    );
  }
}
