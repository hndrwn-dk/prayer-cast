import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/qibla/mosque_cache.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';
import 'package:prayer_cast/qibla/mosque_repository.dart';

const _jakartaLat = -6.2088;
const _jakartaLng = 106.8456;

String _bodyWith(int count) {
  final elements = [
    for (var i = 0; i < count; i++)
      '{"type":"node","id":${100 + i},'
          '"lat":${_jakartaLat + (i + 1) * 0.002},"lon":$_jakartaLng,'
          '"tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid $i"}}',
  ];
  return '{"elements":[${elements.join(',')}]}';
}

MosqueCacheEntry _entry(
  DateTime fetchedAt, {
  String name = 'Masjid Tersimpan',
}) {
  return MosqueCacheEntry(
    mosques: [
      NearbyMosque(
        id: 'node:1',
        name: name,
        kind: NearbyMosqueKind.mosque,
        latitude: _jakartaLat + 0.001,
        longitude: _jakartaLng,
        // Deliberately wrong: a cached row is re-measured against the caller.
        distanceMeters: 99999,
        bearingDegrees: 180,
      ),
    ],
    radiusMeters: 5000,
    fetchedAt: fetchedAt,
  );
}

void main() {
  test('a warm cell is served without touching the network', () async {
    var calls = 0;
    final cache = MemoryMosqueCacheStore();
    await cache.write(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
      _entry(DateTime.now()),
    );
    final repo = MosqueRepository(
      client: MosqueOverpassClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(_bodyWith(6), 200);
        }),
      ),
      cache: cache,
    );

    final result = await repo.nearby(
      latitude: _jakartaLat,
      longitude: _jakartaLng,
    );
    expect(calls, 0);
    expect(result.stale, isFalse);
    expect(result.mosques.single.name, 'Masjid Tersimpan');
    expect(result.radiusMeters, 5000);
  });

  test('cached rows are re-measured against the caller', () async {
    final cache = MemoryMosqueCacheStore();
    await cache.write(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
      _entry(DateTime.now()),
    );
    final repo = MosqueRepository(
      client: MosqueOverpassClient(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      ),
      cache: cache,
    );

    final result = await repo.nearby(
      latitude: _jakartaLat,
      longitude: _jakartaLng,
    );
    expect(result.mosques.single.distanceMeters, closeTo(111, 5));
    expect(result.mosques.single.bearingDegrees, closeTo(0, 1));
  });

  test('an expired cell refreshes and is written back', () async {
    final cache = MemoryMosqueCacheStore();
    final key = mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng);
    await cache.write(
      key,
      _entry(DateTime.now().subtract(const Duration(days: 40))),
    );
    final repo = MosqueRepository(
      client: MosqueOverpassClient(
        httpClient: MockClient((_) async => http.Response(_bodyWith(6), 200)),
      ),
      cache: cache,
    );

    final result = await repo.nearby(
      latitude: _jakartaLat,
      longitude: _jakartaLng,
    );
    expect(result.stale, isFalse);
    expect(result.mosques, hasLength(6));
    expect((await cache.read(key))!.mosques, hasLength(6));
  });

  test('a network failure falls back to the cell, flagged stale', () async {
    final cache = MemoryMosqueCacheStore();
    await cache.write(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
      _entry(DateTime.now().subtract(const Duration(days: 40))),
    );
    final repo = MosqueRepository(
      client: MosqueOverpassClient(
        httpClient: MockClient((_) async => http.Response('busy', 504)),
      ),
      cache: cache,
    );

    final result = await repo.nearby(
      latitude: _jakartaLat,
      longitude: _jakartaLng,
    );
    expect(result.stale, isTrue);
    expect(result.mosques.single.name, 'Masjid Tersimpan');
  });

  test('a network failure with nothing cached still surfaces', () async {
    final repo = MosqueRepository(
      client: MosqueOverpassClient(
        httpClient: MockClient((_) async => http.Response('busy', 504)),
      ),
      cache: MemoryMosqueCacheStore(),
    );
    await expectLater(
      repo.nearby(latitude: _jakartaLat, longitude: _jakartaLng),
      throwsA(isA<MosqueOverpassFailure>()),
    );
  });

  group('prefetch', () {
    test('does nothing over the network when the cell is warm', () async {
      var calls = 0;
      final cache = MemoryMosqueCacheStore();
      await cache.write(
        mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
        _entry(DateTime.now()),
      );
      final repo = MosqueRepository(
        client: MosqueOverpassClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(_bodyWith(6), 200);
          }),
        ),
        cache: cache,
      );

      await repo.prefetch(latitude: _jakartaLat, longitude: _jakartaLng);
      expect(calls, 0);
    });

    test('fills a missing cell', () async {
      var calls = 0;
      final cache = MemoryMosqueCacheStore();
      final repo = MosqueRepository(
        client: MosqueOverpassClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(_bodyWith(6), 200);
          }),
        ),
        cache: cache,
      );

      await repo.prefetch(latitude: _jakartaLat, longitude: _jakartaLng);
      // Ladder always hits 2 km then 5 km before early-stop.
      expect(calls, 2);
      final key = mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng);
      expect((await cache.read(key))!.mosques, hasLength(6));
      expect((await cache.read(key))!.radiusMeters, 5000);
    });

    test('stays silent when there is no cache to warm', () async {
      var calls = 0;
      final repo = MosqueRepository(
        client: MosqueOverpassClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(_bodyWith(6), 200);
          }),
        ),
      );

      await repo.prefetch(latitude: _jakartaLat, longitude: _jakartaLng);
      expect(calls, 0);
    });

    test('swallows a failing refresh', () async {
      final repo = MosqueRepository(
        client: MosqueOverpassClient(
          httpClient: MockClient((_) async => http.Response('busy', 504)),
        ),
        cache: MemoryMosqueCacheStore(),
      );
      await repo.prefetch(latitude: _jakartaLat, longitude: _jakartaLng);
    });
  });
}
