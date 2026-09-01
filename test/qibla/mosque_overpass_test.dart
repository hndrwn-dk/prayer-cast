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
      "tags": { "name": "Masjid Istiqlal" }
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

void main() {
  test('parseOverpassMosques sorts by distance and skips duplicate ids', () {
    final mosques = parseOverpassMosques(
      _overpassBody,
      fromLat: -6.2088,
      fromLng: 106.8456,
    );
    expect(mosques, hasLength(2));
    expect(mosques.first.id, 'node:1');
    expect(mosques.first.name, 'Masjid Istiqlal');
    expect(mosques.last.id, 'way:2');
    expect(mosques.last.name, 'Masjid');
    expect(mosques.first.distanceMeters, lessThan(mosques.last.distanceMeters));
    expect(mosques.first.geoUri.toString(), contains('geo:-6.21,106.845'));
  });

  test('MosqueOverpassClient posts with a PrayerCast User-Agent', () async {
    http.Request? capturedPost;
    final httpClient = MockClient((request) async {
      if (request.method == 'POST') capturedPost = request;
      if (request.method == 'GET') return http.Response('[]', 200);
      return http.Response(_overpassBody, 200);
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
    final mosques = await client.nearby(latitude: -6.2088, longitude: 106.8456);
    expect(capturedPost, isNotNull);
    final post = capturedPost!;
    expect(post.method, 'POST');
    expect(post.url.host, 'overpass.kumi.systems');
    expect(post.headers['User-Agent'], contains('PrayerCast'));
    expect(post.body, contains('religion'));
    expect(post.body, contains('masjid'));
    expect(post.body, contains('building'));
    expect(post.body, isNot(contains('around:')));
    expect(post.body, isNot(contains('nwr')));
    expect(mosques, hasLength(2));
  });

  test('504 on the first interpreter fails over to the next', () async {
    final hosts = <String>[];
    final httpClient = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'overpass.kumi.systems') {
        return http.Response('gateway timeout', 504);
      }
      return http.Response(_overpassBody, 200);
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
    final mosques = await client.nearby(latitude: -6.2088, longitude: 106.8456);
    expect(hosts.take(2), ['overpass.kumi.systems', 'overpass.osm.ch']);
    expect(mosques, hasLength(2));
  });

  test('timed-out Overpass JSON fails over to the next interpreter', () async {
    final hosts = <String>[];
    final httpClient = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'overpass.kumi.systems') {
        return http.Response(
          '{"remark":"runtime error: Query timed out","elements":[]}',
          200,
        );
      }
      return http.Response(_overpassBody, 200);
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
    final mosques = await client.nearby(latitude: -6.2088, longitude: 106.8456);
    expect(hosts.take(2), ['overpass.kumi.systems', 'overpass.osm.ch']);
    expect(mosques, hasLength(2));
  });

  test(
    'empty Overpass on the first interpreter fails over to the next',
    () async {
      final hosts = <String>[];
      final httpClient = MockClient((request) async {
        hosts.add(request.url.host);
        if (request.method == 'GET') return http.Response('[]', 200);
        if (request.url.host == 'overpass.kumi.systems') {
          return http.Response('{"elements":[]}', 200);
        }
        return http.Response(_overpassBody, 200);
      });
      final client = MosqueOverpassClient(httpClient: httpClient);
      final mosques = await client.nearby(
        latitude: -6.2088,
        longitude: 106.8456,
      );
      expect(hosts.take(2), ['overpass.kumi.systems', 'overpass.osm.ch']);
      expect(mosques.first.name, 'Masjid Istiqlal');
    },
  );

  test('all busy interpreters surface a retryable failure', () async {
    final httpClient = MockClient((request) async {
      return http.Response('gateway timeout', 504);
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
    try {
      await client.nearby(latitude: -6.2088, longitude: 106.8456);
      fail('expected MosqueOverpassFailure');
    } on MosqueOverpassFailure catch (e) {
      expect(e.busy, isTrue);
      expect(e.hint(isId: true), contains('sibuk'));
    }
  });

  test('looksLikeMosque keeps musholla and drops roads and churches', () {
    expect(
      looksLikeMosque({'name': 'Musholla Al-Hikmah', 'building': 'yes'}),
      isTrue,
    );
    expect(
      looksLikeMosque({
        'amenity': 'place_of_worship',
        'religion': 'islam',
        'name': 'Masjid Nurul',
      }),
      isTrue,
    );
    expect(
      looksLikeMosque({'highway': 'residential', 'name': 'Jalan Masjid'}),
      isFalse,
    );
    expect(
      looksLikeMosque({
        'amenity': 'place_of_worship',
        'religion': 'christian',
        'name': 'St Mary',
      }),
      isFalse,
    );
    expect(
      looksLikeMosque({
        'amenity': 'school',
        'religion': 'muslim',
        'name': 'Al-Khairiah Islamic School',
      }),
      isFalse,
    );
    expect(
      looksLikeMosque({
        'religion': 'muslim',
        'name': "Muslim Converts' Association of Singapore",
      }),
      isFalse,
    );
    expect(
      looksLikeMosque({
        'amenity': 'grave_yard',
        'religion': 'muslim',
        'name': 'Kubur Kassim',
      }),
      isFalse,
    );
    expect(
      looksLikeMosque({
        'amenity': 'place_of_worship',
        'religion': 'muslim',
        'name': 'Masjid Kampung Siglap',
      }),
      isTrue,
    );
  });

  test('empty Overpass falls back to Nominatim', () async {
    const nominatimBody = '''
[
  {
    "osm_type": "way",
    "osm_id": 99,
    "lat": "1.3140",
    "lon": "103.9210",
    "name": "Masjid Kassim",
    "class": "amenity",
    "type": "mosque"
  }
]
''';
    final hosts = <String>[];
    final httpClient = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host.contains('nominatim')) {
        return http.Response(nominatimBody, 200);
      }
      return http.Response('{"elements":[]}', 200);
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
    final mosques = await client.nearby(latitude: 1.3135, longitude: 103.9205);
    expect(hosts.first, 'overpass.kumi.systems');
    expect(hosts, contains('nominatim.openstreetmap.org'));
    expect(mosques, hasLength(1));
    expect(mosques.first.name, 'Masjid Kassim');
  });

  test('parseNominatimMosques keeps mosques and drops churches', () {
    const body = '''
[
  {
    "osm_type": "way",
    "osm_id": 1,
    "lat": "1.3140",
    "lon": "103.9210",
    "name": "Masjid Kassim",
    "class": "amenity",
    "type": "mosque"
  },
  {
    "osm_type": "way",
    "osm_id": 2,
    "lat": "1.3142",
    "lon": "103.9212",
    "name": "Holy Family",
    "class": "amenity",
    "type": "place_of_worship",
    "extratags": { "religion": "christian" }
  }
]
''';
    final mosques = parseNominatimMosques(
      body,
      fromLat: 1.3135,
      fromLng: 103.9205,
    );
    expect(mosques, hasLength(1));
    expect(mosques.first.id, 'way:1');
    expect(mosques.first.name, 'Masjid Kassim');
  });

  test('mergeMosqueLists dedupes by id and keeps nearest first', () {
    const a = NearbyMosque(
      id: 'way:1',
      name: 'Masjid A',
      latitude: 1.3,
      longitude: 103.9,
      distanceMeters: 400,
    );
    const b = NearbyMosque(
      id: 'way:1',
      name: 'Masjid A dup',
      latitude: 1.3,
      longitude: 103.9,
      distanceMeters: 410,
    );
    const c = NearbyMosque(
      id: 'way:2',
      name: 'Masjid B',
      latitude: 1.31,
      longitude: 103.91,
      distanceMeters: 200,
    );
    final merged = mergeMosqueLists([a], [b, c]);
    expect(merged, hasLength(2));
    expect(merged.first.id, 'way:2');
    expect(merged.last.id, 'way:1');
    expect(merged.last.name, 'Masjid A');
  });

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
    final httpClient = MockClient((request) async {
      captured = request;
      return http.Response(
        '[{"lat":"1.3019","lon":"103.9054","name":"66 Marine Parade"}]',
        200,
      );
    });
    final client = MosqueOverpassClient(httpClient: httpClient);
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
}
