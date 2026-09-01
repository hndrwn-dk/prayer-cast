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
