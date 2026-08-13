import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

const _sampleBody = '''
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
      "latitude": 1.35,
      "longitude": 103.82,
      "timezone": "Asia/Singapore",
      "method": { "id": 11, "name": "MUIS" }
    }
  }
}
''';

void main() {
  late MockClient mockHttp;
  late AladhanClient client;
  late MemoryPrayerPrefsStore store;
  late AdhanNextPrayerProvider provider;

  setUp(() {
    mockHttp = MockClient((request) async {
      return http.Response(_sampleBody, 200);
    });
    client = AladhanClient(httpClient: mockHttp);
    store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
      ),
    );
    provider = AdhanNextPrayerProvider(store: store, client: client);
  });

  test('scheduleForDay returns five Aladhan slots', () async {
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 13),
    );
    expect(day.slots.map((s) => s.name).toList(), [
      'fajr',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ]);
    expect(day.slots[0].scheduledAt.hour, 5);
    expect(day.slots[2].scheduledAt.hour, 15);
  });

  test('next returns asr after dhuhr', () async {
    final next = await provider.next(
      after: DateTime(2026, 8, 13, 12, 1),
    );
    expect(next.name, 'asr');
    expect(next.voiceId, 'standard_adhan');
  });

  test('AladhanClient timingsByCity parses response', () async {
    final schedule = await client.timingsByCity(
      city: 'Singapore',
      country: 'Singapore',
      day: DateTime(2026, 8, 13),
      methodId: 11,
      school: 0,
    );
    expect(schedule.slots, hasLength(5));
    expect(schedule.methodName, 'MUIS');
  });

  test('AladhanClient sends school=1 for Hanafi', () async {
    Uri? seen;
    mockHttp = MockClient((request) async {
      seen = request.url;
      return http.Response(_sampleBody, 200);
    });
    client = AladhanClient(httpClient: mockHttp);
    await client.timingsByCity(
      city: 'Singapore',
      country: 'Singapore',
      day: DateTime(2026, 8, 13),
      methodId: 11,
      school: 1,
    );
    expect(seen!.queryParameters['method'], '11');
    expect(seen!.queryParameters['school'], '1');
  });

  test('hanafi prefs request school=1 and use later Asr', () async {
    mockHttp = MockClient((request) async {
      final school = request.url.queryParameters['school'];
      final asr = school == '1' ? '17:31' : '16:29';
      return http.Response(
        '''
{
  "code": 200,
  "status": "OK",
  "data": {
    "timings": {
      "Fajr": "05:45",
      "Dhuhr": "13:10",
      "Asr": "$asr",
      "Maghrib": "19:15",
      "Isha": "20:26"
    },
    "meta": {
      "latitude": 1.35,
      "longitude": 103.82,
      "timezone": "Asia/Singapore",
      "method": { "id": 11, "name": "MUIS" }
    }
  }
}
''',
        200,
      );
    });
    client = AladhanClient(httpClient: mockHttp);
    store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.hanafi,
        voiceId: 'standard_adhan',
        configured: true,
      ),
    );
    provider = AdhanNextPrayerProvider(store: store, client: client);
    final day = await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 13),
    );
    final asr = day.slots.firstWhere((s) => s.name == 'asr');
    expect(asr.scheduledAt.hour, 17);
    expect(asr.scheduledAt.minute, 31);
    expect(day.slots.firstWhere((s) => s.name == 'maghrib').scheduledAt.hour, 19);
  });

  test('AladhanClient timingsByCoordinates parses response', () async {
    Uri? seen;
    mockHttp = MockClient((request) async {
      seen = request.url;
      return http.Response(_sampleBody, 200);
    });
    client = AladhanClient(httpClient: mockHttp);
    final schedule = await client.timingsByCoordinates(
      latitude: 1.35,
      longitude: 103.82,
      day: DateTime(2026, 8, 13),
      methodId: 11,
      school: 0,
    );
    expect(schedule.slots, hasLength(5));
    expect(seen!.path, contains('/v1/timings/'));
    expect(seen!.queryParameters['latitude'], '1.35');
    expect(seen!.queryParameters['longitude'], '103.82');
    expect(seen!.queryParameters['school'], '0');
    expect(seen!.queryParameters['method'], '11');
  });

  test('provider prefers coordinates when set', () async {
    Uri? seen;
    mockHttp = MockClient((request) async {
      seen = request.url;
      return http.Response(_sampleBody, 200);
    });
    client = AladhanClient(httpClient: mockHttp);
    store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        latitude: 1.29,
        longitude: 103.85,
      ),
    );
    provider = AdhanNextPrayerProvider(store: store, client: client);
    await provider.scheduleForDay(
      prefs: await store.read(),
      day: DateTime(2026, 8, 13),
    );
    expect(seen!.path, contains('/v1/timings/'));
    expect(seen!.queryParameters['latitude'], '1.29');
    expect(seen!.queryParameters['school'], '0');
    expect(seen!.path, isNot(contains('timingsByCity')));
  });
}
