import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';

const _overpassBody = '''
{
  "elements": [
    {
      "type": "node",
      "id": 1,
      "lat": -6.2100,
      "lon": 106.8450,
      "tags": { "amenity": "place_of_worship", "religion": "muslim", "name": "Masjid Istiqlal" }
    },
    {
      "type": "way",
      "id": 2,
      "center": { "lat": -6.1754, "lon": 106.8272 },
      "tags": { "building": "mosque" }
    },
    {
      "type": "node",
      "id": 1,
      "lat": -6.2100,
      "lon": 106.8450,
      "tags": { "name": "duplicate" }
    }
  ]
}
''';

/// [count] mosques strung out roughly north of Jakarta, all far enough apart
/// to survive the 50 m dedupe.
String _bodyWith(int count) {
  final elements = [
    for (var i = 0; i < count; i++)
      '{"type":"node","id":${100 + i},'
          '"lat":${-6.2088 + (i + 1) * 0.002},"lon":106.8456,'
          '"tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid $i"}}',
  ];
  return '{"elements":[${elements.join(',')}]}';
}

int _radiusOf(http.Request request) {
  final match = RegExp(r'around%3A(\d+)').firstMatch(request.body);
  return int.parse(match!.group(1)!);
}

void main() {
  group('query', () {
    test('is a tag union around the point, with no name matching', () {
      final query = mosqueOverpassQuery(
        latitude: -6.2088,
        longitude: 106.8456,
        radiusMeters: 2000,
      );
      expect(
        query,
        contains(
          'nwr["amenity"="place_of_worship"]["religion"="muslim"](around:2000,-6.208800,106.845600);',
        ),
      );
      expect(query, contains('nwr["building"="mosque"](around:2000,'));
      expect(query, contains('nwr["room"="prayer_room"](around:2000,'));
      expect(query, contains('out center 60;'));
      expect(query, isNot(contains('masjid')));
      expect(query, isNot(contains('~')));
    });
  });

  group('parsing', () {
    test('sorts by distance and skips duplicate ids', () {
      final mosques = parseOverpassMosques(
        _overpassBody,
        fromLat: -6.2088,
        fromLng: 106.8456,
      );
      expect(mosques, hasLength(2));
      expect(mosques.first.id, 'node:1');
      expect(mosques.first.name, 'Masjid Istiqlal');
      expect(mosques.first.kind, NearbyMosqueKind.mosque);
      expect(mosques.last.id, 'way:2');
      expect(mosques.last.name, isEmpty);
      expect(mosques.last.kind, NearbyMosqueKind.mosque);
      expect(
        mosques.first.distanceMeters,
        lessThan(mosques.last.distanceMeters),
      );
      expect(
        mosques.first.geoUri('Masjid Istiqlal').toString(),
        contains('geo:-6.21,106.845'),
      );
    });

    test('keeps unnamed prayer rooms and labels them', () {
      const body = '''
{
  "elements": [
    {
      "type": "node",
      "id": 7,
      "lat": -6.2090,
      "lon": 106.8460,
      "tags": { "room": "prayer_room" }
    }
  ]
}
''';
      final mosques = parseOverpassMosques(
        body,
        fromLat: -6.2088,
        fromLng: 106.8456,
      );
      expect(mosques, hasLength(1));
      expect(mosques.single.isNamed, isFalse);
      expect(mosques.single.kind, NearbyMosqueKind.prayerRoom);
      expect(mosques.single.label(isId: false), 'Prayer room');
      expect(mosques.single.label(isId: true), 'Musholla');
    });

    test('carries a bearing from the origin', () {
      const body = '''
{
  "elements": [
    { "type": "node", "id": 9, "lat": -6.1988, "lon": 106.8456,
      "tags": { "building": "mosque", "name": "Masjid Utara" } }
  ]
}
''';
      final mosques = parseOverpassMosques(
        body,
        fromLat: -6.2088,
        fromLng: 106.8456,
      );
      expect(mosques.single.bearingDegrees, closeTo(0, 1));
    });
  });

  group('filters', () {
    test(
      'looksLikeMosque keeps the queried tags and drops other religions',
      () {
        expect(
          looksLikeMosque({
            'amenity': 'place_of_worship',
            'religion': 'muslim',
          }),
          isTrue,
        );
        expect(looksLikeMosque({'building': 'mosque'}), isTrue);
        expect(looksLikeMosque({'room': 'prayer_room'}), isTrue);
        expect(
          looksLikeMosque({
            'amenity': 'place_of_worship',
            'religion': 'christian',
            'name': 'St Mary',
          }),
          isFalse,
        );
        // No tag match; a mosque-sounding name alone is not enough any more.
        expect(
          looksLikeMosque({'highway': 'residential', 'name': 'Jalan Masjid'}),
          isFalse,
        );
      },
    );

    test('drops disused, ruined, and under-construction places', () {
      expect(
        looksLikeMosque({
          'disused:amenity': 'place_of_worship',
          'religion': 'muslim',
        }),
        isFalse,
      );
      expect(
        looksLikeMosque({'building': 'mosque', 'historic': 'ruins'}),
        isFalse,
      );
      expect(looksLikeMosque({'building': 'construction'}), isFalse);
      expect(
        looksLikeMosque({'building': 'mosque', 'construction': 'yes'}),
        isFalse,
      );
      expect(
        looksLikeMosque({'building': 'mosque', 'disused': 'yes'}),
        isFalse,
      );
    });

    test('mosque label needs building=mosque or a Masjid-style name', () {
      expect(
        mosqueKindFor({'building': 'mosque'}, ''),
        NearbyMosqueKind.mosque,
      );
      expect(
        mosqueKindFor({'amenity': 'place_of_worship'}, 'Masjid Al-Ikhlas'),
        NearbyMosqueKind.mosque,
      );
      expect(
        mosqueKindFor({'amenity': 'place_of_worship'}, 'Surau Kampung'),
        NearbyMosqueKind.prayerRoom,
      );
    });
  });

  group('dedupe', () {
    NearbyMosque at(String id, String name, double lat, double distance) {
      return NearbyMosque(
        id: id,
        name: name,
        kind: NearbyMosqueKind.mosque,
        latitude: lat,
        longitude: 106.8456,
        distanceMeters: distance,
        bearingDegrees: 0,
      );
    }

    test('merges a node inside its own way when names agree', () {
      final merged = dedupeNearbyMosques([
        at('way:1', 'Masjid Al-Ikhlas', -6.2100, 140),
        at('node:2', 'Al Ikhlas', -6.21002, 142),
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'way:1');
    });

    test(
      'an unnamed twin donates nothing but a named one donates its name',
      () {
        final merged = dedupeNearbyMosques([
          at('way:1', '', -6.2100, 140),
          at('node:2', 'Masjid Jami', -6.21002, 142),
        ]);
        expect(merged, hasLength(1));
        expect(merged.single.id, 'way:1');
        expect(merged.single.name, 'Masjid Jami');
      },
    );

    test('keeps two different mosques on the same block', () {
      final merged = dedupeNearbyMosques([
        at('way:1', 'Masjid Al-Ikhlas', -6.2100, 140),
        at('node:2', 'Masjid Nurul Huda', -6.21002, 142),
      ]);
      expect(merged, hasLength(2));
    });

    test('keeps same-named mosques that are far apart', () {
      final merged = dedupeNearbyMosques([
        at('way:1', 'Masjid Al-Ikhlas', -6.2100, 140),
        at('node:2', 'Masjid Al-Ikhlas', -6.2200, 1400),
      ]);
      expect(merged, hasLength(2));
    });
  });

  group('radius ladder', () {
    test('stops at the first tier that answers well enough', () async {
      final radii = <int>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          radii.add(_radiusOf(request));
          return http.Response(_bodyWith(6), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(radii, [2000]);
      expect(page.radiusMeters, 2000);
      expect(page.mosques, hasLength(6));
    });

    test('climbs while a tier is too thin, then stops', () async {
      final radii = <int>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          final radius = _radiusOf(request);
          radii.add(radius);
          return http.Response(_bodyWith(radius == 2000 ? 1 : 6), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(radii, [2000, 5000]);
      expect(page.radiusMeters, 5000);
      expect(page.mosques, hasLength(6));
    });

    test('returns the best tier when none reaches the bar', () async {
      final radii = <int>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          final radius = _radiusOf(request);
          radii.add(radius);
          return http.Response(_bodyWith(radius ~/ 2000), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(radii, [2000, 5000, 10000]);
      expect(page.radiusMeters, 10000);
      expect(page.mosques, hasLength(5));
    });

    test('an honestly empty area is not an error', () async {
      final client = MosqueOverpassClient(
        httpClient: MockClient(
          (_) async => http.Response('{"elements":[]}', 200),
        ),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(page.mosques, isEmpty);
      expect(page.radiusMeters, 10000);
    });
  });

  group('endpoints', () {
    test('posts to lz4 first with a PrayerCast User-Agent', () async {
      http.Request? captured;
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(_bodyWith(6), 200);
        }),
      );
      await client.nearby(latitude: -6.2088, longitude: 106.8456);
      final post = captured!;
      expect(post.method, 'POST');
      expect(post.url.host, 'lz4.overpass-api.de');
      expect(post.headers['User-Agent'], contains('PrayerCast'));
      expect(post.headers['User-Agent'], contains('tursinalabs.com'));
      expect(post.body, contains('nwr'));
      expect(post.body, contains('around'));
    });

    test('504 on lz4 fails over to z', () async {
      final hosts = <String>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host.startsWith('lz4')) {
            return http.Response('gateway timeout', 504);
          }
          return http.Response(_bodyWith(6), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(hosts, ['lz4.overpass-api.de', 'z.overpass-api.de']);
      expect(page.mosques, hasLength(6));
    });

    test('a timed-out Overpass body fails over too', () async {
      final hosts = <String>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host.startsWith('lz4')) {
            return http.Response(
              '{"remark":"runtime error: Query timed out","elements":[]}',
              200,
            );
          }
          return http.Response(_bodyWith(6), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(hosts, ['lz4.overpass-api.de', 'z.overpass-api.de']);
      expect(page.mosques, hasLength(6));
    });

    test('every interpreter busy surfaces a retryable failure', () async {
      final client = MosqueOverpassClient(
        httpClient: MockClient((_) async => http.Response('busy', 504)),
      );
      await expectLater(
        client.nearby(latitude: -6.2088, longitude: 106.8456),
        throwsA(
          isA<MosqueOverpassFailure>()
              .having((e) => e.busy, 'busy', isTrue)
              .having((e) => e.hint(isId: true), 'hint', contains('sibuk')),
        ),
      );
    });
  });

  test('the total budget stops the ladder early', () async {
    final base = DateTime.utc(2026, 1, 1);
    var call = 0;
    final requests = <String>[];
    final client = MosqueOverpassClient(
      httpClient: MockClient((request) async {
        requests.add(request.url.host);
        throw TimeoutException('slow');
      }),
      totalBudget: const Duration(seconds: 25),
      clock: () => base.add(Duration(seconds: 10 * call++)),
    );
    await expectLater(
      client.nearby(latitude: -6.2088, longitude: 106.8456),
      throwsA(isA<MosqueOverpassFailure>()),
    );
    // Two attempts fit in 25 s; the remaining tiers are abandoned rather than
    // left running while the user waits.
    expect(requests, hasLength(2));
  });

  group('geocoding', () {
    test('parseNominatimGeocode reads the first hit', () {
      const body = '''
[
  {
    "lat": "1.3019",
    "lon": "103.9054",
    "name": "66 Marine Parade"
  }
]
''';
      final hit = parseNominatimGeocode(body);
      expect(hit, isNotNull);
      expect(hit!.latitude, closeTo(1.3019, 0.0001));
      expect(hit.longitude, closeTo(103.9054, 0.0001));
      expect(hit.name, '66 Marine Parade');
    });

    test('geocodeAddress GETs Nominatim with the typed query', () async {
      late http.Request captured;
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            '[{"lat":"1.3019","lon":"103.9054","name":"66 Marine Parade"}]',
            200,
          );
        }),
      );
      final hit = await client.geocodeAddress(
        query: '66 Marine Parade, Singapore, Singapore',
        nearLat: 1.3135,
        nearLng: 103.9205,
      );
      expect(captured.method, 'GET');
      expect(captured.url.host, 'nominatim.openstreetmap.org');
      expect(captured.url.queryParameters['q'], contains('Marine Parade'));
      expect(captured.headers['User-Agent'], contains('PrayerCast'));
      expect(hit?.name, '66 Marine Parade');
    });
  });
}
