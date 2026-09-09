import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/qibla/mosque_cache.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';
import 'package:prayer_cast/qibla/qibla_location.dart';
import 'package:prayer_cast/qibla/qibla_providers.dart';
import 'package:prayer_cast/qibla/ui/mosque_map_page.dart';

const _jakartaLat = -6.2088;
const _jakartaLng = 106.8456;

const _overpassBody = '''
{
  "elements": [
    {
      "type": "node",
      "id": 11,
      "lat": -6.2100,
      "lon": 106.8450,
      "tags": {
        "amenity": "place_of_worship",
        "religion": "muslim",
        "name": "Masjid Istiqlal"
      }
    }
  ]
}
''';

const _unnamedBody = '''
{
  "elements": [
    {
      "type": "node",
      "id": 21,
      "lat": -6.2098,
      "lon": 106.8456,
      "tags": { "room": "prayer_room" }
    }
  ]
}
''';

const _jakartaFix = QiblaFix(
  latitude: _jakartaLat,
  longitude: _jakartaLng,
  label: 'Jakarta, Indonesia',
  source: QiblaLocationSource.coordinates,
);

const _cityFix = QiblaFix(
  latitude: _jakartaLat,
  longitude: _jakartaLng,
  label: 'Jakarta, Indonesia',
  source: QiblaLocationSource.cityCatalog,
);

void _sizePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 20, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 20, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required MockClient httpClient,
  QiblaFix fix = _jakartaFix,
  Locale locale = const Locale('en'),
  MosqueCacheStore? cache,
}) async {
  _sizePhone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mosqueOverpassClientProvider.overrideWithValue(
          MosqueOverpassClient(httpClient: httpClient),
        ),
        if (cache != null) mosqueCacheStoreProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MosqueMapPage(fix: fix),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    debugMosqueSearchOrigin = () async => (fix: null, permissionDenied: false);
  });
  tearDown(() {
    debugMosqueSearchOrigin = null;
  });

  testWidgets('lists Overpass mosques under the map', (tester) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
      locale: const Locale('id'),
    );

    expect(find.text('Masjid terdekat'), findsOneWidget);
    expect(find.text('ARAH SHOLAT'), findsOneWidget);
    expect(find.text('OPENSTREETMAP'), findsNothing);
    expect(find.text('Masjid Istiqlal'), findsOneWidget);
    expect(find.textContaining('GPS saat ini'), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_list')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mosque_map_origin_marker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mosque_map_address_field')),
      findsOneWidget,
    );
  });

  testWidgets('English header is Nearby mosques, not OPENSTREETMAP', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
    );

    expect(find.text('Nearby mosques'), findsOneWidget);
    expect(find.text('PRAYER DIRECTION'), findsOneWidget);
    expect(find.text('OPENSTREETMAP'), findsNothing);
    expect(find.textContaining('current GPS'), findsOneWidget);
    expect(find.textContaining('Address or postcode'), findsOneWidget);
  });

  testWidgets('rows carry distance with a bearing, and an unnamed label', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_unnamedBody, 200)),
    );

    expect(find.text('Prayer room'), findsOneWidget);
    // A shade over 100 m due north-ish of the origin.
    expect(find.textContaining('m \u00B7 '), findsOneWidget);
    expect(find.textContaining('\u00B7 S'), findsOneWidget);
  });

  testWidgets('the footer credits OSM and says searches are not saved', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mosque_map_privacy')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('mosque_map_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text("Searches aren't saved."), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_list_credit')), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_credit')), findsOneWidget);
  });

  testWidgets('tapping a row selects it and grows its pin', (tester) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
    );

    double pinWidth() {
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer).last);
      return layer.markers
          .firstWhere(
            (m) => m.key == const ValueKey<String>('mosque_marker_node:11'),
          )
          .width;
    }

    final before = pinWidth();

    await tester.tap(find.byKey(const ValueKey('mosque_row_node:11')));
    await tester.pump();

    expect(pinWidth(), greaterThan(before));
  });

  testWidgets('opening in maps is an icon, not a Maps text column', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
    );

    expect(find.text('Maps'), findsNothing);
    expect(find.byKey(const ValueKey('mosque_open_node:11')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mosque_open_node:11')),
        matching: find.byIcon(Icons.directions_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('searching an address moves the origin via Nominatim', (
    tester,
  ) async {
    final queries = <String>[];
    await _pumpMap(
      tester,
      fix: const QiblaFix(
        latitude: 1.3135,
        longitude: 103.9205,
        label: 'Singapore, Singapore',
        source: QiblaLocationSource.coordinates,
      ),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          queries.add(request.url.queryParameters['q'] ?? '');
          return http.Response(
            '[{"lat":"1.3019","lon":"103.9054","name":"66 Marine Parade"}]',
            200,
          );
        }
        return http.Response(_overpassBody, 200);
      }),
    );

    await tester.enterText(
      find.byKey(const ValueKey('mosque_map_address_field')),
      '66 Marine Parade',
    );
    await tester.tap(find.byKey(const ValueKey('mosque_map_address_search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(queries.any((q) => q.contains('66 Marine Parade')), isTrue);
    expect(queries.any((q) => q.contains('Singapore')), isTrue);
    expect(find.textContaining('from the place you searched'), findsOneWidget);
  });

  testWidgets('panning alone never re-searches; Search here does', (
    tester,
  ) async {
    final searched = <String>[];
    await _pumpMap(
      tester,
      httpClient: MockClient((request) async {
        searched.add(request.body);
        return http.Response(_overpassBody, 200);
      }),
    );
    final beforePan = searched.length;

    // A nudge well inside a quarter of the 2 km radius.
    await tester.drag(find.byType(FlutterMap), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mosque_map_search_here')), findsNothing);

    await tester.drag(find.byType(FlutterMap), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mosque_map_search_here')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mosque_map_center_pin')), findsOneWidget);
    expect(searched, hasLength(beforePan));

    await tester.tap(find.byKey(const ValueKey('mosque_map_search_here')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(searched.length, greaterThan(beforePan));
    expect(find.byKey(const ValueKey('mosque_map_search_here')), findsNothing);
  });

  testWidgets('denied permission with only a city offers an address search', (
    tester,
  ) async {
    debugMosqueSearchOrigin = () async => (fix: null, permissionDenied: true);
    var searched = 0;
    await _pumpMap(
      tester,
      fix: _cityFix,
      httpClient: MockClient((_) async {
        searched++;
        return http.Response(_overpassBody, 200);
      }),
    );

    expect(searched, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Location permission is off'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mosque_map_address_field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mosque_map_list')), findsNothing);
    expect(find.byKey(const ValueKey('mosque_map_retry')), findsNothing);
  });

  testWidgets('denied permission still uses a saved GPS fix', (tester) async {
    debugMosqueSearchOrigin = () async => (fix: null, permissionDenied: true);
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response(_overpassBody, 200)),
    );

    expect(find.text('Masjid Istiqlal'), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_no_origin')), findsNothing);
  });

  testWidgets('a failed refresh shows cached rows with a stale note', (
    tester,
  ) async {
    final cache = MemoryMosqueCacheStore();
    await cache.write(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
      MosqueCacheEntry(
        mosques: const [
          NearbyMosque(
            id: 'node:99',
            name: 'Masjid Tersimpan',
            kind: NearbyMosqueKind.mosque,
            latitude: -6.2098,
            longitude: 106.8456,
            distanceMeters: 0,
            bearingDegrees: 0,
          ),
        ],
        radiusMeters: 5000,
        fetchedAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    );

    await _pumpMap(
      tester,
      cache: cache,
      httpClient: MockClient((_) async => http.Response('busy', 504)),
    );

    expect(find.text('Masjid Tersimpan'), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_stale')), findsOneWidget);
    expect(find.text('No network. Showing saved results.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_retry')), findsNothing);
  });

  testWidgets('a hard failure with no cache offers a retry, not a spinner', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      httpClient: MockClient((_) async => http.Response('busy', 504)),
    );

    expect(find.byKey(const ValueKey('mosque_map_retry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
