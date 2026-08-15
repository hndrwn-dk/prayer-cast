import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/indonesia_location.dart';
import 'package:prayer_cast/prayer_times/kemenag_city_index.dart';
import 'package:prayer_cast/prayer_times/kemenag_client.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

const _jadwalBody = '''
{
  "status": true,
  "data": {
    "id": 1301,
    "lokasi": "KOTA JAKARTA",
    "daerah": "DKI JAKARTA",
    "jadwal": {
      "tanggal": "Sabtu, 15/08/2026",
      "imsak": "04:33",
      "subuh": "04:43",
      "terbit": "05:57",
      "dhuha": "06:25",
      "dzuhur": "12:01",
      "ashar": "15:21",
      "maghrib": "17:58",
      "isya": "19:08",
      "date": "2026-08-15"
    }
  }
}
''';

const _aladhanBody = '''
{
  "code": 200,
  "status": "OK",
  "data": {
    "timings": {
      "Fajr": "05:00",
      "Dhuhr": "12:00",
      "Asr": "15:30",
      "Maghrib": "18:00",
      "Isha": "19:30"
    },
    "meta": {
      "latitude": -6.2,
      "longitude": 106.8,
      "timezone": "Asia/Jakarta",
      "method": { "id": 11, "name": "MUIS" }
    }
  }
}
''';

void main() {
  final cities = KemenagCityIndex.bundled();

  group('city match', () {
    test('Jakarta maps to KOTA JAKARTA', () {
      expect(cities.match(city: 'Jakarta')?.id, '1301');
      expect(cities.match(city: 'Jakarta Selatan')?.id, '1301');
      expect(cities.match(city: 'DKI Jakarta')?.id, '1301');
    });

    test('Bandung prefers KOTA over kabupaten', () {
      expect(cities.match(city: 'Bandung')?.id, '1219');
      expect(cities.match(city: 'Kota Bandung')?.lokasi, 'KOTA BANDUNG');
    });

    test('Surabaya maps to KOTA SURABAYA', () {
      expect(cities.match(city: 'Surabaya')?.id, '1638');
    });

    test('kabupaten Sleman matches', () {
      expect(cities.match(city: 'Sleman')?.id, '1504');
      expect(cities.match(city: 'Kabupaten Sleman')?.lokasi, 'KAB. SLEMAN');
    });

    test('unknown city returns null', () {
      expect(cities.match(city: 'Atlantis'), isNull);
      expect(cities.match(city: ''), isNull);
    });

    test('admin area can resolve a kelurahan-style city', () {
      expect(
        cities.match(city: 'Menteng', adminArea: 'Jakarta Pusat')?.id,
        '1301',
      );
      expect(
        cities.match(city: 'Condongcatur', adminArea: 'Kabupaten Sleman')?.id,
        '1504',
      );
      expect(
        cities.match(city: 'Condongcatur', adminArea: 'Sleman')?.lokasi,
        'KAB. SLEMAN',
      );
    });

    test('unknown kelurahan without admin area does not guess a city', () {
      expect(cities.match(city: 'Menteng'), isNull);
      expect(cities.match(city: 'Condongcatur'), isNull);
      expect(cities.match(city: 'Menteng', adminArea: ''), isNull);
    });
  });

  test('parseJadwal maps five slots and ignores Imsak', () {
    final day = KemenagClient.parseJadwal(
      {
        'status': true,
        'data': {
          'lokasi': 'KOTA JAKARTA',
          'jadwal': {
            'imsak': '04:33',
            'subuh': '04:43',
            'dzuhur': '12:01',
            'ashar': '15:21',
            'maghrib': '17:58',
            'isya': '19:08',
          },
        },
      },
      day: DateTime(2026, 8, 15),
    );
    expect(day.slots.map((s) => s.name).toList(), [
      'fajr',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ]);
    expect(day.slots[0].scheduledAt.hour, 4);
    expect(day.slots[0].scheduledAt.minute, 43);
    expect(day.slots[2].scheduledAt.hour, 15);
    expect(day.methodName, contains('Kemenag'));
    expect(day.sourceKey, 'kemenag');
    expect(day.slots.any((s) => s.scheduledAt.hour == 4 && s.scheduledAt.minute == 33),
        isFalse);
  });

  test('timingsForPlace uses admin area for kelurahan match, not GPS query',
      () async {
    Uri? seen;
    final client = KemenagClient(
      httpClient: MockClient((request) async {
        seen = request.url;
        return http.Response(_jadwalBody, 200);
      }),
      cityIndex: cities,
    );
    final day = await client.timingsForPlace(
      city: 'Menteng',
      adminArea: 'Jakarta Pusat',
      day: DateTime(2026, 8, 15),
      latitude: -6.186,
      longitude: 106.833,
    );
    expect(seen!.host, 'api.myquran.com');
    expect(seen!.path, contains('/v2/sholat/jadwal/1301/'));
    expect(seen!.queryParameters, isEmpty);
    expect(day.sourceKey, 'kemenag');
    expect(day.methodName, contains('Kemenag'));
  });

  test('timingsForPlace hits city-id path not coordinates', () async {
    Uri? seen;
    final client = KemenagClient(
      httpClient: MockClient((request) async {
        seen = request.url;
        return http.Response(_jadwalBody, 200);
      }),
      cityIndex: cities,
    );
    final day = await client.timingsForPlace(
      city: 'Jakarta',
      day: DateTime(2026, 8, 15),
    );
    expect(seen!.host, 'api.myquran.com');
    expect(seen!.path, contains('/v2/sholat/jadwal/1301/2026/8/15'));
    expect(seen!.queryParameters.containsKey('latitude'), isFalse);
    expect(day.slots, hasLength(5));
  });

  test('unknown city throws KemenagCityNotFound', () async {
    final client = KemenagClient(
      httpClient: MockClient((request) async => http.Response('no', 500)),
      cityIndex: cities,
    );
    expect(
      () => client.timingsForPlace(city: 'Atlantis', day: DateTime(2026, 8, 15)),
      throwsA(isA<KemenagCityNotFound>()),
    );
  });

  test('HTTP error throws KemenagApiFailure', () async {
    final client = KemenagClient(
      httpClient: MockClient((request) async => http.Response('down', 503)),
      cityIndex: cities,
    );
    expect(
      () => client.timingsForPlace(city: 'Jakarta', day: DateTime(2026, 8, 15)),
      throwsA(isA<KemenagApiFailure>()),
    );
  });

  test('provider falls back to Aladhan MUIS when city is unknown', () async {
    Uri? seen;
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Atlantis',
        country: 'Indonesia',
        methodId: kemenagMethodId,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
      ),
    );
    final provider = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async {
          seen = request.url;
          return http.Response(_aladhanBody, 200);
        }),
      ),
      kemenagClient: KemenagClient(
        httpClient: MockClient((request) async => http.Response('no', 500)),
        cityIndex: cities,
      ),
    );
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 15),
    );
    expect(seen!.host, 'api.aladhan.com');
    expect(seen!.queryParameters['method'], '11');
    expect(day.methodName, 'MUIS');
    expect(day.sourceKey, 'aladhan');
    expect(provider.lastFallbackMessage, contains('Atlantis'));
  });

  test('provider falls back to Aladhan when Kemenag HTTP fails', () async {
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Jakarta',
        country: 'Indonesia',
        methodId: kemenagMethodId,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
      ),
    );
    final provider = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async {
          return http.Response(_aladhanBody, 200);
        }),
      ),
      kemenagClient: KemenagClient(
        httpClient: MockClient((request) async => http.Response('down', 503)),
        cityIndex: cities,
      ),
    );
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 15),
    );
    expect(day.methodName, 'MUIS');
    expect(day.sourceKey, isNot('kemenag'));
    expect(provider.lastFallbackMessage, isNotNull);
  });

  test('provider uses persisted admin area to match kelurahan to Kemenag',
      () async {
    Uri? seen;
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Menteng',
        country: 'Indonesia',
        methodId: kemenagMethodId,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        administrativeArea: 'Jakarta Pusat',
      ),
    );
    final provider = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async {
          fail('Aladhan should not run when Kemenag matches');
        }),
      ),
      kemenagClient: KemenagClient(
        httpClient: MockClient((request) async {
          seen = request.url;
          return http.Response(_jadwalBody, 200);
        }),
        cityIndex: cities,
      ),
    );
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 15),
    );
    expect(seen!.host, 'api.myquran.com');
    expect(seen!.path, contains('/v2/sholat/jadwal/1301/'));
    expect(seen!.queryParameters.containsKey('latitude'), isFalse);
    expect(day.sourceKey, 'kemenag');
    expect(day.methodName, contains('Kemenag'));
    expect(provider.lastFallbackMessage, isNull);
  });

  test('provider falls back without Kemenag label for unknown kelurahan',
      () async {
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Menteng',
        country: 'Indonesia',
        methodId: kemenagMethodId,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
      ),
    );
    final provider = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async {
          return http.Response(_aladhanBody, 200);
        }),
      ),
      kemenagClient: KemenagClient(
        httpClient: MockClient((request) async => http.Response('no', 500)),
        cityIndex: cities,
      ),
    );
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 15),
    );
    expect(day.methodName, 'MUIS');
    expect(day.sourceKey, 'aladhan');
    expect(day.methodName.toLowerCase(), isNot(contains('kemenag')));
    expect(provider.lastFallbackMessage, contains('Menteng'));
  });

  test('cache location key includes source so ID and SG do not collide', () {
    const jakarta = PrayerPrefs(
      city: 'Jakarta',
      country: 'Indonesia',
      methodId: kemenagMethodId,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
    );
    const singapore = PrayerPrefs(
      city: 'Singapore',
      country: 'Singapore',
      methodId: 11,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
    );
    final idKey = AdhanNextPrayerProvider.locationKeyFor(jakarta);
    final sgKey = AdhanNextPrayerProvider.locationKeyFor(singapore);
    expect(idKey, startsWith('kemenag|'));
    expect(sgKey, startsWith('aladhan|'));
    expect(idKey, isNot(sgKey));
    expect(idKey, contains('Jakarta'));
    expect(sgKey, contains('Singapore'));
  });

  test('cache location key includes administrative area', () {
    const menteng = PrayerPrefs(
      city: 'Menteng',
      country: 'Indonesia',
      methodId: kemenagMethodId,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
      administrativeArea: 'Jakarta Pusat',
    );
    const mentengOnly = PrayerPrefs(
      city: 'Menteng',
      country: 'Indonesia',
      methodId: kemenagMethodId,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
    );
    final withAdmin = AdhanNextPrayerProvider.locationKeyFor(menteng);
    final withoutAdmin = AdhanNextPrayerProvider.locationKeyFor(mentengOnly);
    expect(withAdmin, contains('Jakarta Pusat'));
    expect(withAdmin, isNot(withoutAdmin));
  });
}
