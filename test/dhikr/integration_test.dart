import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_scheduler.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dhikr_integration');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('adhkar prefs persist and drive the scheduler', () async {
    final file = File('${tempDir.path}/adhkar_prefs.txt');
    final prefs = FileAdhkarPrefs(file);
    await prefs.setEnabled(AdhkarType.morning, true);
    await prefs.setDelayMinutes(AdhkarType.morning, 15);
    await prefs.save();

    final reloaded = FileAdhkarPrefs(file);
    await reloaded.load();
    expect(reloaded.enabled(AdhkarType.morning), isTrue);
    expect(reloaded.enabled(AdhkarType.evening), isFalse);
    expect(reloaded.delayMinutes(AdhkarType.morning), 15);

    final scheduled = AdhkarScheduler(reloaded).getScheduledAdhkar({
      'fajr': DateTime(2026, 10, 14, 5, 30),
      'dhuhr': DateTime(2026, 10, 14, 12),
    });
    expect(scheduled[AdhkarType.morning], DateTime(2026, 10, 14, 5, 45));
    expect(scheduled.containsKey(AdhkarType.evening), isFalse);
  });

  test('counter store persists independent counters across reload', () async {
    final file = File('${tempDir.path}/dhikr_counter.json');
    final store = FileDhikrCounterStore(file);
    for (var i = 0; i < 3; i++) {
      await store.increment('subhanallah', target: 33);
    }
    await store.increment('alhamdulillah', target: 33);
    await store.reset('subhanallah');

    final reloaded = FileDhikrCounterStore(file);
    expect((await reloaded.get('subhanallah'))?.count, 0);
    expect((await reloaded.get('alhamdulillah'))?.count, 1);
    expect((await reloaded.get('alhamdulillah'))?.target, 33);
  });
}
