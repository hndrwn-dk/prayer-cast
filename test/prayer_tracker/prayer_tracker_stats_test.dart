import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_stats.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_store.dart';

void main() {
  test('week stats count elapsed slots, streak, and strongest prayer', () {
    final now = DateTime(2026, 9, 1);
    final storeDays = <String, PrayerDayLog>{};
    void put(
      DateTime day,
      Map<String, PrayerLogEntry> log,
    ) {
      storeDays[FilePrayerTrackerStore.dayKey(day)] = log;
    }

    put(DateTime(2026, 8, 26), {
      'fajr': const PrayerLogEntry(
        timing: PrayerLogTiming.onTime,
        where: PrayerLogWhere.alone,
      ),
    });
    put(DateTime(2026, 8, 27), {
      for (final p in kTrackedPrayers)
        p: const PrayerLogEntry(
          timing: PrayerLogTiming.onTime,
          where: PrayerLogWhere.jamaah,
        ),
    });
    put(DateTime(2026, 8, 28), {
      'fajr': const PrayerLogEntry(timing: PrayerLogTiming.late),
      'dhuhr': const PrayerLogEntry(where: PrayerLogWhere.alone),
      'asr': const PrayerLogEntry(
        timing: PrayerLogTiming.onTime,
        where: PrayerLogWhere.jamaah,
      ),
    });
    put(DateTime(2026, 8, 29), {
      'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
      'isha': const PrayerLogEntry(where: PrayerLogWhere.alone),
    });
    put(DateTime(2026, 8, 30), {
      'fajr': const PrayerLogEntry(
        timing: PrayerLogTiming.onTime,
        where: PrayerLogWhere.jamaah,
      ),
      'maghrib': const PrayerLogEntry(timing: PrayerLogTiming.late),
    });
    put(DateTime(2026, 8, 31), {
      'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
    });
    put(DateTime(2026, 9, 1), {
      'fajr': const PrayerLogEntry(
        timing: PrayerLogTiming.onTime,
        where: PrayerLogWhere.alone,
      ),
      'dhuhr': const PrayerLogEntry(where: PrayerLogWhere.jamaah),
    });

    final stats = PrayerStatsCalculator.compute(
      now: now,
      period: PrayerStatsPeriod.week,
      days: storeDays,
    );

    expect(stats.elapsedDays, 7);
    expect(stats.possibleSlots, 35);
    expect(stats.loggedSlots, 16);
    expect(stats.daysComplete, 1);
    expect(stats.streakDays, 7);
    expect(stats.loggedByPrayer['fajr'], 7);
    expect(stats.strongestPrayer, 'fajr');
    expect(stats.weakestPrayer, 'asr');
    expect(stats.onTime, 11);
    expect(stats.late, 2);
    expect(stats.jamaah, 8);
    expect(stats.alone, 4);
    expect(stats.insight(isId: true), contains('Rantai 7 hari'));
  });

  test('unfinished today does not break yesterday streak', () {
    final now = DateTime(2026, 9, 1);
    final stats = PrayerStatsCalculator.compute(
      now: now,
      period: PrayerStatsPeriod.week,
      days: {
        '2026-08-30': {
          'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
        },
        '2026-08-31': {
          'dhuhr': const PrayerLogEntry(where: PrayerLogWhere.alone),
        },
      },
    );
    expect(stats.streakDays, 2);
    expect(stats.loggedSlots, 2);
  });

  test('year range starts January 1 and buckets months', () {
    final now = DateTime(2026, 9, 1);
    final from = PrayerStatsCalculator.startOf(now, PrayerStatsPeriod.year);
    expect(from, DateTime(2026, 1, 1));
    final stats = PrayerStatsCalculator.compute(
      now: now,
      period: PrayerStatsPeriod.year,
      days: {
        '2026-01-15': {
          'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
        },
        '2026-09-01': {
          'isha': const PrayerLogEntry(where: PrayerLogWhere.jamaah),
        },
      },
    );
    expect(stats.possibleSlots, 244 * 5);
    expect(stats.loggedSlots, 2);
    expect(stats.months.first.month, 1);
    expect(stats.months.last.month, 9);
    expect(stats.months.first.loggedSlots, 1);
  });

  test('memory store readRange is inclusive', () async {
    final store = MemoryPrayerTrackerStore();
    await store.writeDay('2026-08-30', {
      'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
    });
    await store.writeDay('2026-09-01', {
      'asr': const PrayerLogEntry(where: PrayerLogWhere.alone),
    });
    await store.writeDay('2026-09-02', {
      'isha': const PrayerLogEntry(timing: PrayerLogTiming.late),
    });
    final range = await store.readRange('2026-08-31', '2026-09-01');
    expect(range.containsKey('2026-08-30'), isFalse);
    expect(range.containsKey('2026-09-01'), isTrue);
    expect(range.containsKey('2026-09-02'), isFalse);
  });

  test('observations skip negative when nothing was late', () {
    final stats = PrayerStatsCalculator.compute(
      now: DateTime(2026, 9, 1),
      period: PrayerStatsPeriod.week,
      days: {
        '2026-08-31': {
          'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
          'dhuhr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
        },
      },
    );
    final notes = stats.observations(isId: false);
    expect(notes, isNotEmpty);
    expect(notes.where((n) => !n.positive), isEmpty);
    expect(notes.first.text.toLowerCase(), contains('fajr'));
  });

  test('observations flag the prayer with the most lates', () {
    final stats = PrayerStatsCalculator.compute(
      now: DateTime(2026, 9, 1),
      period: PrayerStatsPeriod.week,
      days: {
        '2026-08-31': {
          'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
          'isha': const PrayerLogEntry(timing: PrayerLogTiming.late),
        },
      },
    );
    final notes = stats.observations(isId: false);
    expect(notes.where((n) => !n.positive).single.text, contains('Isha'));
    expect(notes.where((n) => !n.positive).single.text, contains('late once'));
  });
}
