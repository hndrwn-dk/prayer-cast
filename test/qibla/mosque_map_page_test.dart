import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';
import 'package:prayer_cast/qibla/qibla_location.dart';
import 'package:prayer_cast/qibla/qibla_providers.dart';
import 'package:prayer_cast/qibla/ui/mosque_map_page.dart';

const _overpassBody = '''
{
  "elements": [
    {
      "type": "node",
      "id": 11,
      "lat": -6.2100,
      "lon": 106.8450,
      "tags": { "name": "Masjid Istiqlal" }
    }
  ]
}
''';

void main() {
  setUp(() {
    debugMosqueSearchOrigin = () async => null;
  });
  tearDown(() {
    debugMosqueSearchOrigin = null;
  });

  testWidgets('lists Overpass mosques under the map', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 20, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 20, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mosqueOverpassClientProvider.overrideWithValue(
            MosqueOverpassClient(
              httpClient: MockClient(
                (_) async => http.Response(_overpassBody, 200),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MosqueMapPage(
            fix: QiblaFix(
              latitude: -6.2088,
              longitude: 106.8456,
              label: 'Jakarta, Indonesia',
              source: QiblaLocationSource.coordinates,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Masjid terdekat'), findsOneWidget);
    expect(find.text('ARAH SHOLAT'), findsOneWidget);
    expect(find.text('OPENSTREETMAP'), findsNothing);
    expect(find.text('OpenStreetMap'), findsNothing);
    expect(find.text('Masjid Istiqlal'), findsOneWidget);
    expect(find.textContaining('GPS saat ini'), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque_map_center_pin')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mosque_map_address_field')),
      findsOneWidget,
    );
  });

  testWidgets('English header is Nearby mosques, not OPENSTREETMAP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mosqueOverpassClientProvider.overrideWithValue(
            MosqueOverpassClient(
              httpClient: MockClient(
                (_) async => http.Response(_overpassBody, 200),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MosqueMapPage(
            fix: QiblaFix(
              latitude: -6.2088,
              longitude: 106.8456,
              label: 'Jakarta, Indonesia',
              source: QiblaLocationSource.coordinates,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Nearby mosques'), findsOneWidget);
    expect(find.text('PRAYER DIRECTION'), findsOneWidget);
    expect(find.text('OPENSTREETMAP'), findsNothing);
    expect(find.textContaining('current GPS'), findsOneWidget);
    expect(find.textContaining('Address or postcode'), findsOneWidget);
  });

  testWidgets('searching an address moves the pin via Nominatim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final queries = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mosqueOverpassClientProvider.overrideWithValue(
            MosqueOverpassClient(
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
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MosqueMapPage(
            fix: QiblaFix(
              latitude: 1.3135,
              longitude: 103.9205,
              label: 'Singapore, Singapore',
              source: QiblaLocationSource.coordinates,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const ValueKey('mosque_map_address_field')),
      '66 Marine Parade',
    );
    await tester.tap(find.byKey(const ValueKey('mosque_map_address_search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(queries.any((q) => q.contains('66 Marine Parade')), isTrue);
    expect(queries.any((q) => q.contains('Singapore')), isTrue);
    expect(
      find.textContaining('Reopen the page to use GPS again'),
      findsOneWidget,
    );
  });
}
