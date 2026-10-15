import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';

void main() {
  group('FileDhikrCounterStore', () {
    late Directory tempDir;
    late File storeFile;
    late FileDhikrCounterStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dhikr_counter_test');
      storeFile = File('${tempDir.path}/dhikr_counter.json');
      store = FileDhikrCounterStore(storeFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null for missing counter', () async {
      final state = await store.get('subhanallah');
      expect(state, isNull);
    });

    test('increments counter and persists', () async {
      await store.increment('subhanallah', target: 33);
      final state = await store.get('subhanallah');
      expect(state?.count, 1);
      expect(state?.target, 33);

      await store.increment('subhanallah', target: 33);
      final state2 = await store.get('subhanallah');
      expect(state2?.count, 2);
    });

    test('resets counter to zero', () async {
      await store.increment('subhanallah', target: 33);
      await store.increment('subhanallah', target: 33);
      expect((await store.get('subhanallah'))?.count, 2);

      await store.reset('subhanallah');
      final state = await store.get('subhanallah');
      expect(state?.count, 0);
      expect(state?.target, 33);
    });

    test('manages multiple counters independently', () async {
      await store.increment('subhanallah', target: 33);
      await store.increment('alhamdulillah', target: 100);
      await store.increment('alhamdulillah', target: 100);

      final state1 = await store.get('subhanallah');
      final state2 = await store.get('alhamdulillah');

      expect(state1?.count, 1);
      expect(state2?.count, 2);
    });

    test('decrement undoes a tap and persists', () async {
      await store.increment('subhanallah', target: 33);
      await store.increment('subhanallah', target: 33);
      await store.decrement('subhanallah');

      expect((await store.get('subhanallah'))?.count, 1);
      final reloaded = FileDhikrCounterStore(storeFile);
      expect((await reloaded.get('subhanallah'))?.count, 1);
    });

    test('decrement on a missing or zero counter is a no-op', () async {
      await store.decrement('subhanallah');
      expect(await store.get('subhanallah'), isNull);

      await store.setTarget('subhanallah', 33);
      await store.decrement('subhanallah');
      expect((await store.get('subhanallah'))?.count, 0);
    });

    test('rapid unawaited increments all land on disk', () async {
      final writes = [
        for (var i = 0; i < 20; i++) store.increment('subhanallah', target: 33),
      ];
      await Future.wait(writes);

      final reloaded = FileDhikrCounterStore(storeFile);
      expect((await reloaded.get('subhanallah'))?.count, 20);
    });

    test('persists across store instances', () async {
      await store.increment('subhanallah', target: 33);
      await store.increment('subhanallah', target: 33);

      final newStore = FileDhikrCounterStore(storeFile);
      final state = await newStore.get('subhanallah');
      expect(state?.count, 2);
      expect(state?.target, 33);
    });

    test('updates target without changing count', () async {
      await store.increment('subhanallah', target: 33);
      await store.increment('subhanallah', target: 33);
      await store.setTarget('subhanallah', 100);

      final state = await store.get('subhanallah');
      expect(state?.count, 2);
      expect(state?.target, 100);
    });

    test('handles entries with wrong shape gracefully', () async {
      await storeFile.writeAsString('{"a": {"dhikrId": "a"}}');
      final newStore = FileDhikrCounterStore(storeFile);
      expect(await newStore.get('a'), isNull);
    });

    test('handles corrupted JSON gracefully', () async {
      await storeFile.writeAsString('not valid json {{{');
      final newStore = FileDhikrCounterStore(storeFile);
      final state = await newStore.get('subhanallah');
      expect(state, isNull);
    });
  });
}
