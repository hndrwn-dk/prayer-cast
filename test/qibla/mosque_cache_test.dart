import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prayer_cast/qibla/mosque_cache.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';

NearbyMosque _mosque(String id, {String name = 'Masjid Istiqlal'}) {
  return NearbyMosque(
    id: id,
    name: name,
    kind: NearbyMosqueKind.mosque,
    latitude: -6.2100,
    longitude: 106.8450,
    distanceMeters: 140,
    bearingDegrees: 200,
  );
}

void main() {
  group('cache key', () {
    test('snaps coordinates to a 0.01 degree cell', () {
      expect(
        mosqueCacheKey(latitude: -6.2088, longitude: 106.8456),
        mosqueCacheKey(latitude: -6.2112, longitude: 106.8478),
      );
      expect(
        mosqueCacheKey(latitude: -6.2088, longitude: 106.8456),
        isNot(mosqueCacheKey(latitude: -6.2288, longitude: 106.8456)),
      );
    });

    test('never writes a negative zero cell', () {
      expect(mosqueCacheKey(latitude: -0.004, longitude: -0.001), '0.00,0.00');
    });
  });

  group('entry', () {
    test('round-trips through JSON', () {
      final entry = MosqueCacheEntry(
        mosques: [
          _mosque('node:1'),
          _mosque('way:2', name: ''),
        ],
        radiusMeters: 5000,
        fetchedAt: DateTime.utc(2026, 1, 2, 3, 4),
      );
      final restored = MosqueCacheEntry.fromJson(entry.toJson())!;
      expect(restored.radiusMeters, 5000);
      expect(restored.fetchedAt, entry.fetchedAt);
      expect(restored.mosques, hasLength(2));
      expect(restored.mosques.first.name, 'Masjid Istiqlal');
      expect(restored.mosques.first.kind, NearbyMosqueKind.mosque);
      expect(restored.mosques.last.isNamed, isFalse);
    });

    test('is fresh for 30 days and stale after', () {
      final fetchedAt = DateTime.utc(2026, 1, 1);
      final entry = MosqueCacheEntry(
        mosques: const [],
        radiusMeters: 2000,
        fetchedAt: fetchedAt,
      );
      expect(entry.isFreshAt(fetchedAt.add(const Duration(days: 29))), isTrue);
      expect(entry.isFreshAt(fetchedAt.add(const Duration(days: 31))), isFalse);
    });
  });

  group('FileMosqueCacheStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mosque_cache_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    File cacheFile() => File(p.join(dir.path, 'mosque_cache.json'));

    test('writes and reads back a cell', () async {
      final store = FileMosqueCacheStore(cacheFile());
      final entry = MosqueCacheEntry(
        mosques: [_mosque('node:1')],
        radiusMeters: 2000,
        fetchedAt: DateTime.now(),
      );
      await store.write('a', entry);

      final reopened = FileMosqueCacheStore(cacheFile());
      final read = await reopened.read('a');
      expect(read, isNotNull);
      expect(read!.mosques.single.id, 'node:1');
      expect(read.radiusMeters, 2000);
    });

    test('drops expired cells on load', () async {
      final now = DateTime.utc(2026, 6, 1);
      final store = FileMosqueCacheStore(cacheFile(), clock: () => now);
      await store.write(
        'old',
        MosqueCacheEntry(
          mosques: [_mosque('node:1')],
          radiusMeters: 2000,
          fetchedAt: now,
        ),
      );

      final later = FileMosqueCacheStore(
        cacheFile(),
        clock: () => now.add(const Duration(days: 40)),
      );
      expect(await later.read('old'), isNull);
    });

    test('a corrupt file reads as an empty cache, not an error', () async {
      await cacheFile().writeAsString('not json');
      final store = FileMosqueCacheStore(cacheFile());
      expect(await store.read('a'), isNull);
    });

    test('keeps the cell count bounded', () async {
      final now = DateTime.utc(2026, 6, 1);
      var tick = 0;
      final store = FileMosqueCacheStore(
        cacheFile(),
        clock: () => now.add(Duration(minutes: tick)),
      );
      for (var i = 0; i < kMosqueCacheMaxCells + 4; i++) {
        tick = i;
        await store.write(
          'cell_$i',
          MosqueCacheEntry(
            mosques: [_mosque('node:$i')],
            radiusMeters: 2000,
            fetchedAt: now.add(Duration(minutes: i)),
          ),
        );
      }
      expect(await store.read('cell_0'), isNull);
      expect(await store.read('cell_${kMosqueCacheMaxCells + 3}'), isNotNull);
    });
  });
}
