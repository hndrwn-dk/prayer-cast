import 'prayer_tracker_store.dart';

const kTrackedPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

class PrayerStatInsight {
  const PrayerStatInsight({required this.positive, required this.text});

  final bool positive;
  final String text;
}

enum PrayerStatsPeriod { week, month, year }

class PrayerDayPulse {
  const PrayerDayPulse({required this.day, required this.loggedCount});

  final DateTime day;
  final int loggedCount;
}

class PrayerMonthBucket {
  const PrayerMonthBucket({
    required this.month,
    required this.loggedSlots,
    required this.possibleSlots,
  });

  final int month;
  final int loggedSlots;
  final int possibleSlots;
}

class PrayerPeriodStats {
  const PrayerPeriodStats({
    required this.period,
    required this.from,
    required this.to,
    required this.possibleSlots,
    required this.loggedSlots,
    required this.daysLogged,
    required this.daysComplete,
    required this.streakDays,
    required this.onTime,
    required this.late,
    required this.jamaah,
    required this.alone,
    required this.loggedByPrayer,
    required this.onTimeByPrayer,
    required this.lateByPrayer,
    required this.pulses,
    required this.months,
  });

  final PrayerStatsPeriod period;
  final DateTime from;
  final DateTime to;
  final int possibleSlots;
  final int loggedSlots;
  final int daysLogged;
  final int daysComplete;
  final int streakDays;
  final int onTime;
  final int late;
  final int jamaah;
  final int alone;
  final Map<String, int> loggedByPrayer;
  final Map<String, int> onTimeByPrayer;
  final Map<String, int> lateByPrayer;
  final List<PrayerDayPulse> pulses;
  final List<PrayerMonthBucket> months;

  int get elapsedDays => pulses.length;

  int get timedSlots => onTime + late;

  int get placedSlots => jamaah + alone;

  int get completionPercent {
    if (possibleSlots <= 0) return 0;
    return ((loggedSlots / possibleSlots) * 100).round();
  }

  int get onTimePercent {
    if (timedSlots <= 0) return 0;
    return ((onTime / timedSlots) * 100).round();
  }

  int get jamaahPercent {
    if (placedSlots <= 0) return 0;
    return ((jamaah / placedSlots) * 100).round();
  }

  String? get strongestPrayer => _extremePrayer(highest: true);

  String? get weakestPrayer => _extremePrayer(highest: false);

  String? _extremePrayer({required bool highest}) {
    if (loggedSlots == 0) return null;
    String? pick;
    var best = highest ? -1 : 1 << 20;
    for (final prayer in kTrackedPrayers) {
      final count = loggedByPrayer[prayer] ?? 0;
      if (highest) {
        if (count > best) {
          best = count;
          pick = prayer;
        }
      } else if (count < best) {
        best = count;
        pick = prayer;
      }
    }
    return pick;
  }

  String? insight({required bool isId}) {
    if (loggedSlots == 0) {
      return isId
          ? 'Mulai tandai sholat hari ini. Statistik mengisi sendiri.'
          : 'Log today\'s prayers. Stats fill in as you go.';
    }
    if (streakDays >= 3) {
      return isId
          ? 'Rantai $streakDays hari. Jangan putus hari ini.'
          : '$streakDays-day streak. Keep it going today.';
    }
    final strong = strongestPrayer;
    final weak = weakestPrayer;
    if (strong != null &&
        weak != null &&
        strong != weak &&
        (loggedByPrayer[strong] ?? 0) - (loggedByPrayer[weak] ?? 0) >= 2) {
      return isId
          ? '${_prayerId(strong)} paling konsisten. ${_prayerId(weak)} paling sering terlewat.'
          : '${_prayerEn(strong)} is your strongest. ${_prayerEn(weak)} is missed most.';
    }
    if (timedSlots >= 5 && onTimePercent >= 70) {
      return isId
          ? '$onTimePercent% tepat waktu. Ritme Anda sudah bagus.'
          : '$onTimePercent% on time. Your rhythm is holding.';
    }
    if (placedSlots >= 5 && jamaahPercent >= 40) {
      return isId
          ? '$jamaahPercent% jamaah. Masjid jadi kebiasaan.'
          : '$jamaahPercent% in mosque. Jamaah is becoming a habit.';
    }
    if (completionPercent < 50) {
      return isId
          ? '$loggedSlots dari $possibleSlots sholat tercatat. Satu chip sudah cukup untuk mulai.'
          : '$loggedSlots of $possibleSlots prayers logged. One chip is enough to start.';
    }
    return isId
        ? '$loggedSlots dari $possibleSlots sholat tercatat periode ini.'
        : '$loggedSlots of $possibleSlots prayers logged this period.';
  }

  /// One or two short observations for the Insights block. Negative is omitted
  /// unless a prayer was actually logged late.
  List<PrayerStatInsight> observations({required bool isId}) {
    if (loggedSlots == 0) {
      return [
        PrayerStatInsight(
          positive: true,
          text: isId
              ? 'Mulai tandai sholat hari ini. Statistik mengisi sendiri.'
              : 'Log today\'s prayers. Stats fill in as you go.',
        ),
      ];
    }

    final out = <PrayerStatInsight>[];
    final positive = _positiveObservation(isId: isId);
    if (positive != null) out.add(positive);
    final attention = _attentionObservation(isId: isId);
    if (attention != null) out.add(attention);
    return out;
  }

  PrayerStatInsight? _positiveObservation({required bool isId}) {
    if (streakDays >= 3) {
      return PrayerStatInsight(
        positive: true,
        text: isId
            ? 'Rantai $streakDays hari. Jangan putus hari ini.'
            : '$streakDays-day streak. Keep it going today.',
      );
    }
    final timedLeaders = _prayersAtBestOnTime();
    if (timedLeaders.length >= 2) {
      final a = _name(timedLeaders[0], isId);
      final b = _name(timedLeaders[1], isId);
      return PrayerStatInsight(
        positive: true,
        text: isId
            ? '$a dan $b paling konsisten periode ini.'
            : '$a and $b are your most consistent prayers this period.',
      );
    }
    if (timedLeaders.length == 1) {
      final name = _name(timedLeaders.first, isId);
      return PrayerStatInsight(
        positive: true,
        text: isId
            ? '$name paling konsisten periode ini.'
            : '$name is your most consistent prayer this period.',
      );
    }
    final strong = strongestPrayer;
    if (strong == null) return null;
    final name = _name(strong, isId);
    return PrayerStatInsight(
      positive: true,
      text: isId
          ? '$name paling sering tercatat periode ini.'
          : '$name is logged most often this period.',
    );
  }

  PrayerStatInsight? _attentionObservation({required bool isId}) {
    String? pick;
    var mostLate = 0;
    var worstPct = 2.0;
    for (final prayer in kTrackedPrayers) {
      final lateCount = lateByPrayer[prayer] ?? 0;
      if (lateCount <= 0) continue;
      final onTimeCount = onTimeByPrayer[prayer] ?? 0;
      final timed = onTimeCount + lateCount;
      final pct = timed == 0 ? 1.0 : onTimeCount / timed;
      if (lateCount > mostLate ||
          (lateCount == mostLate && pct < worstPct)) {
        mostLate = lateCount;
        worstPct = pct;
        pick = prayer;
      }
    }
    if (pick == null || mostLate <= 0) return null;
    final name = _name(pick, isId);
    if (mostLate == 1) {
      return PrayerStatInsight(
        positive: false,
        text: isId
            ? '$name tercatat terlambat sekali. Coba pengingat 15 menit lebih awal.'
            : '$name was logged late once. Try a reminder 15 minutes earlier.',
      );
    }
    return PrayerStatInsight(
      positive: false,
      text: isId
          ? '$name terlambat $mostLate kali. Pengingat 15 menit mungkin membantu.'
          : '$name was late $mostLate times. A 15-minute reminder may help.',
    );
  }

  List<String> _prayersAtBestOnTime() {
    var best = -1.0;
    final top = <String>[];
    for (final prayer in kTrackedPrayers) {
      final onTimeCount = onTimeByPrayer[prayer] ?? 0;
      final lateCount = lateByPrayer[prayer] ?? 0;
      final timed = onTimeCount + lateCount;
      if (timed <= 0) continue;
      final pct = onTimeCount / timed;
      if (pct > best + 1e-9) {
        best = pct;
        top
          ..clear()
          ..add(prayer);
      } else if ((pct - best).abs() < 1e-9) {
        top.add(prayer);
      }
    }
    return top;
  }

  static String _name(String key, bool isId) =>
      isId ? _prayerId(key) : _prayerEn(key);

  static String _prayerId(String key) => switch (key) {
        'fajr' => 'Subuh',
        'dhuhr' => 'Zuhur',
        'asr' => 'Asar',
        'maghrib' => 'Magrib',
        'isha' => 'Isya',
        _ => key,
      };

  static String _prayerEn(String key) => switch (key) {
        'fajr' => 'Fajr',
        'dhuhr' => 'Dhuhr',
        'asr' => 'Asr',
        'maghrib' => 'Maghrib',
        'isha' => 'Isha',
        _ => key,
      };
}

abstract final class PrayerStatsCalculator {
  static DateTime startOf(DateTime now, PrayerStatsPeriod period) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      PrayerStatsPeriod.week => today.subtract(const Duration(days: 6)),
      PrayerStatsPeriod.month => today.subtract(const Duration(days: 29)),
      PrayerStatsPeriod.year => DateTime(today.year, 1, 1),
    };
  }

  static PrayerPeriodStats compute({
    required DateTime now,
    required PrayerStatsPeriod period,
    required Map<String, PrayerDayLog> days,
  }) {
    final to = DateTime(now.year, now.month, now.day);
    final from = startOf(now, period);
    final dates = _datesInclusive(from, to);
    final pulses = <PrayerDayPulse>[];
    final loggedByPrayer = {for (final p in kTrackedPrayers) p: 0};
    final onTimeByPrayer = {for (final p in kTrackedPrayers) p: 0};
    final lateByPrayer = {for (final p in kTrackedPrayers) p: 0};
    var loggedSlots = 0;
    var daysLogged = 0;
    var daysComplete = 0;
    var onTime = 0;
    var late = 0;
    var jamaah = 0;
    var alone = 0;

    for (final day in dates) {
      final key = FilePrayerTrackerStore.dayKey(day);
      final log = days[key] ?? const {};
      var dayCount = 0;
      for (final prayer in kTrackedPrayers) {
        final entry = log[prayer];
        if (entry == null || entry.isEmpty) continue;
        dayCount++;
        loggedByPrayer[prayer] = (loggedByPrayer[prayer] ?? 0) + 1;
        if (entry.timing == PrayerLogTiming.onTime) {
          onTime++;
          onTimeByPrayer[prayer] = (onTimeByPrayer[prayer] ?? 0) + 1;
        }
        if (entry.timing == PrayerLogTiming.late) {
          late++;
          lateByPrayer[prayer] = (lateByPrayer[prayer] ?? 0) + 1;
        }
        if (entry.where == PrayerLogWhere.jamaah) jamaah++;
        if (entry.where == PrayerLogWhere.alone) alone++;
      }
      loggedSlots += dayCount;
      if (dayCount > 0) daysLogged++;
      if (dayCount >= kTrackedPrayers.length) daysComplete++;
      pulses.add(PrayerDayPulse(day: day, loggedCount: dayCount));
    }

    return PrayerPeriodStats(
      period: period,
      from: from,
      to: to,
      possibleSlots: dates.length * kTrackedPrayers.length,
      loggedSlots: loggedSlots,
      daysLogged: daysLogged,
      daysComplete: daysComplete,
      streakDays: _streak(pulses),
      onTime: onTime,
      late: late,
      jamaah: jamaah,
      alone: alone,
      loggedByPrayer: loggedByPrayer,
      onTimeByPrayer: onTimeByPrayer,
      lateByPrayer: lateByPrayer,
      pulses: pulses,
      months: _months(pulses),
    );
  }

  static List<DateTime> _datesInclusive(DateTime from, DateTime to) {
    final out = <DateTime>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!cursor.isAfter(last)) {
      out.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return out;
  }

  static int _streak(List<PrayerDayPulse> pulses) {
    if (pulses.isEmpty) return 0;
    var i = pulses.length - 1;
    if (pulses[i].loggedCount == 0 && i > 0) i--;
    var streak = 0;
    for (; i >= 0; i--) {
      if (pulses[i].loggedCount == 0) break;
      streak++;
    }
    return streak;
  }

  static List<PrayerMonthBucket> _months(List<PrayerDayPulse> pulses) {
    if (pulses.isEmpty) return const [];
    final buckets = <int, PrayerMonthBucket>{};
    for (final pulse in pulses) {
      final month = pulse.day.month;
      final existing = buckets[month] ??
          PrayerMonthBucket(month: month, loggedSlots: 0, possibleSlots: 0);
      buckets[month] = PrayerMonthBucket(
        month: month,
        loggedSlots: existing.loggedSlots + pulse.loggedCount,
        possibleSlots: existing.possibleSlots + kTrackedPrayers.length,
      );
    }
    final keys = buckets.keys.toList()..sort();
    return [for (final key in keys) buckets[key]!];
  }
}
