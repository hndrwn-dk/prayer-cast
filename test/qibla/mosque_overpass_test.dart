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

    test(
      'keeps seven distinct Masjid-prefixed mosques inside 2 km (no dedupe collapse)',
      () {
        // Realistic Overpass shape: several named mosques near Marine Parade,
        // all sharing the "Masjid" prefix, spaced like real OSM ways (some
        // pairs within 50 m, most farther). None must collapse.
        const body = '''
{
  "elements": [
    {"type":"way","id":595932319,"center":{"lat":1.3145,"lon":103.9110},
     "tags":{"amenity":"place_of_worship","religion":"muslim","building":"mosque","name":"Masjid Abdul Aleem Siddique"}},
    {"type":"way","id":308900485,"center":{"lat":1.3148,"lon":103.9112},
     "tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid Khalid"}},
    {"type":"way","id":1197550458,"center":{"lat":1.3025,"lon":103.8920},
     "tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid Taha"}},
    {"type":"way","id":170417140,"center":{"lat":1.3160,"lon":103.9000},
     "tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid Darul Aman"}},
    {"type":"way","id":306119361,"center":{"lat":1.3050,"lon":103.8950},
     "tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid Kassim"}},
    {"type":"way","id":401190523,"center":{"lat":1.3180,"lon":103.9050},
     "tags":{"amenity":"place_of_worship","religion":"muslim","building":"mosque","name":"Masjid Wak Tanjong"}},
    {"type":"way","id":453583783,"center":{"lat":1.3165,"lon":103.9200},
     "tags":{"amenity":"place_of_worship","religion":"muslim","building":"mosque","name":"Masjid Kampung Siglap"}},
    {"type":"node","id":9001,"lat":1.31451,"lon":103.91101,
     "tags":{"amenity":"place_of_worship","religion":"muslim","name":"Masjid Abdul Aleem Siddique"}}
  ]
}
''';
        final parsed = parseOverpassMosquesDetailed(
          body,
          fromLat: 1.3020,
          fromLng: 103.9065,
        );
        expect(parsed.stats.rawElements, 8);
        // Node+way twins of the same named mosque merge; the other six stay.
        expect(parsed.stats.afterFilter, 8);
        expect(parsed.stats.afterDedupe, 7);
        expect(parsed.stats.afterCap, 7);
        expect(parsed.mosques, hasLength(7));
        final names = parsed.mosques.map((m) => m.name).toSet();
        expect(names, contains('Masjid Abdul Aleem Siddique'));
        expect(names, contains('Masjid Khalid'));
        expect(names, contains('Masjid Kampung Siglap'));
        expect(names, hasLength(7));
      },
    );

    test('reports stage counts when nothing is dropped', () {
      final parsed = parseOverpassMosquesDetailed(
        _overpassBody,
        fromLat: -6.2088,
        fromLng: 106.8456,
      );
      expect(parsed.stats.rawElements, 3);
      expect(parsed.stats.afterFilter, 2);
      expect(parsed.stats.afterDedupe, 2);
      expect(parsed.stats.afterCap, 2);
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

    test('drops only explicit disused:/ruins/construction tags', () {
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
      expect(
        looksLikeMosque({'building': 'mosque', 'construction': 'yes'}),
        isFalse,
      );
      // A plain active mosque must not be dropped for unrelated tag text.
      expect(
        looksLikeMosque({
          'amenity': 'place_of_worship',
          'religion': 'muslim',
          'name': 'Masjid Construction Road',
          'description': 'near the old ruins',
        }),
        isTrue,
      );
      // building=construction alone is not the construction=* key.
      expect(looksLikeMosque({'building': 'mosque'}), isTrue);
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

    test('does not merge on shared generic tokens alone', () {
      final merged = dedupeNearbyMosques([
        at('way:1', 'Masjid Jami', -6.2100, 140),
        at('node:2', 'Masjid Raya', -6.21002, 142),
        at('node:3', 'Mosque Surau', -6.21004, 144),
      ]);
      expect(merged, hasLength(3));
      expect(
        mosqueNamesSimilar('Masjid Jami', 'Masjid Raya'),
        isFalse,
      );
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
    test('always tries 5 km before early-stop, even when 2 km is dense', () async {
      final radii = <int>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          radii.add(_radiusOf(request));
          return http.Response(_bodyWith(6), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(radii, [2000, 5000]);
      expect(page.radiusMeters, 5000);
      expect(page.mosques, hasLength(6));
    });

    test('climbs while a tier is too thin, then stops at 5 km+', () async {
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

    test('widens to 10 km when every lower tier is below the bar', () async {
      final radii = <int>[];
      final client = MosqueOverpassClient(
        httpClient: MockClient((request) async {
          final radius = _radiusOf(request);
          radii.add(radius);
          // 1 at 2km, 2 at 5km, 6 at 10km — must climb all the way.
          final count = switch (radius) {
            2000 => 1,
            5000 => 2,
            _ => 6,
          };
          return http.Response(_bodyWith(count), 200);
        }),
      );
      final page = await client.nearby(latitude: -6.2088, longitude: 106.8456);
      expect(radii, [2000, 5000, 10000]);
      expect(page.radiusMeters, 10000);
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
      // 2 km: lz4 fails, z answers; 5 km: lz4 answers and early-stops.
      expect(hosts, [
        'lz4.overpass-api.de',
        'z.overpass-api.de',
        'z.overpass-api.de',
      ]);
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
      expect(hosts, [
        'lz4.overpass-api.de',
        'z.overpass-api.de',
        'z.overpass-api.de',
      ]);
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
