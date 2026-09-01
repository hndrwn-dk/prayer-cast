import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_store.dart';

void main() {
  test('write and read today log with timing and where', () async {
    final store = MemoryPrayerTrackerStore();
    final key = FilePrayerTrackerStore.dayKey(DateTime(2026, 9, 1));
    await store.writeDay(key, {
      'fajr': const PrayerLogEntry(
        timing: PrayerLogTiming.onTime,
        where: PrayerLogWhere.alone,
      ),
      'maghrib': const PrayerLogEntry(where: PrayerLogWhere.jamaah),
    });
    final log = await store.readDay(key);
    expect(log['fajr']?.timing, PrayerLogTiming.onTime);
    expect(log['fajr']?.where, PrayerLogWhere.alone);
    expect(log['maghrib']?.timing, isNull);
    expect(log['maghrib']?.where, PrayerLogWhere.jamaah);
    expect(log.containsKey('dhuhr'), isFalse);
  });

  test('qadha ledger persists beside days and stays out of readRange', () async {
    final file = await _tempFile();
    final store = FilePrayerTrackerStore(file);
    await store.writeDay('2026-09-01', {
      'fajr': const PrayerLogEntry(timing: PrayerLogTiming.onTime),
    });
    await store.writeQadha(
      const QadhaLedger(counts: {'fajr': 2, 'isha': 1}),
    );

    final ledger = await store.readQadha();
    expect(ledger.of('fajr'), 2);
    expect(ledger.of('isha'), 1);
    expect(ledger.total, 3);

    final range = await store.readRange('2026-01-01', '2026-12-31');
    expect(range.keys, ['2026-09-01']);
    expect(range.containsKey(kQadhaCacheKey), isFalse);

    final reloaded = FilePrayerTrackerStore(file);
    expect((await reloaded.readQadha()).total, 3);
  });

  test('migrates legacy single-status wire values', () async {
    final file = await _tempFile();
    final store = FilePrayerTrackerStore(file);
    await file.writeAsString(
      '{"2026-09-01":{"fajr":"onTime","asr":"jamaah","isha":"alone"}}',
    );
    final log = await store.readDay('2026-09-01');
    expect(log['fajr']?.timing, PrayerLogTiming.onTime);
    expect(log['asr']?.where, PrayerLogWhere.jamaah);
    expect(log['isha']?.where, PrayerLogWhere.alone);
  });
}

Future<File> _tempFile() async {
  final dir = await Directory.systemTemp.createTemp('prayer_tracker_test');
  return File('${dir.path}/tracker.json');
}
