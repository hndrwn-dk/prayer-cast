import 'dart:async';
import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/qibla/compass_heading.dart';
import 'package:prayer_cast/qibla/mosque_cache.dart';
import 'package:prayer_cast/qibla/mosque_overpass.dart';
import 'package:prayer_cast/qibla/qibla_bearing.dart';
import 'package:prayer_cast/qibla/qibla_haptics.dart';
import 'package:prayer_cast/qibla/qibla_providers.dart';
import 'package:prayer_cast/qibla/ui/qibla_compass_dial.dart';
import 'package:prayer_cast/qibla/ui/qibla_page.dart';

const double _jakartaLat = -6.2088;
const double _jakartaLng = 106.8456;

PrayerPrefs _jakartaPrefs() {
  return PrayerPrefs.defaults.copyWith(
    city: 'Jakarta',
    country: 'Indonesia',
    latitude: _jakartaLat,
    longitude: _jakartaLng,
    configured: true,
  );
}

double _jakartaQibla() {
  return qiblaBearingDegrees(latitude: _jakartaLat, longitude: _jakartaLng);
}

Future<void> _pumpQibla(
  WidgetTester tester, {
  required PrayerPrefs prefs,
  required Stream<CompassReading> readings,
  QiblaHaptics? haptics,
  Locale locale = const Locale('en'),
  MosqueCacheStore? mosqueCache,
  MockClient? mosqueHttp,
}) async {
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
        prayerPrefsStoreProvider.overrideWithValue(
          MemoryPrayerPrefsStore(prefs),
        ),
        compassHeadingSourceProvider.overrideWithValue(
          StreamCompassHeadingSource(readings),
        ),
        if (haptics != null) qiblaHapticsProvider.overrideWithValue(haptics),
        if (mosqueCache != null)
          mosqueCacheStoreProvider.overrideWithValue(mosqueCache),
        if (mosqueHttp != null)
          mosqueOverpassClientProvider.overrideWithValue(
            MosqueOverpassClient(httpClient: mosqueHttp),
          ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QiblaPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Riverpod flushes provider notifications on the frame after the event, so
/// a second pump is needed before the new reading is on screen.
Future<void> _pushHeading(
  WidgetTester tester,
  StreamController<CompassReading> controller,
  double headingDeg,
) async {
  controller.add(CompassReading.live(headingDeg: headingDeg));
  await tester.pump();
  await tester.pump();
}

Color? _actionColor(WidgetTester tester, String key) {
  return tester
      .widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Material),
            )
            .first,
      )
      .color;
}

void main() {
  testWidgets('shows Jakarta bearing and nearby-mosques action', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 0),
      ),
    );

    expect(find.text('Qibla'), findsOneWidget);
    expect(find.byKey(const ValueKey('qibla_bearing_label')), findsOneWidget);
    final bearingText = tester
        .widget<Text>(find.byKey(const ValueKey('qibla_bearing_label')))
        .data!;
    expect(bearingText, contains('WNW'));
    expect(find.text('Nearby mosques'), findsOneWidget);
    expect(find.text('Facing qibla'), findsNothing);
    expect(find.text('Turn until the needle points up'), findsOneWidget);
  });

  testWidgets('nearby mosques is demoted to match change location', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 0),
      ),
    );

    final mosques = _actionColor(tester, 'qibla_open_mosques');
    final settings = _actionColor(tester, 'qibla_open_settings');
    expect(mosques, settings);
    expect(mosques, isNot(PrayerCastColors.leaf));
  });

  testWidgets('aligned heading shows facing copy and taps once', (
    tester,
  ) async {
    final haptics = RecordingQiblaHaptics();
    final qibla = _jakartaQibla();
    final controller = StreamController<CompassReading>.broadcast();
    addTearDown(controller.close);

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: controller.stream,
      haptics: haptics,
    );

    await _pushHeading(tester, controller, qibla);
    expect(find.text('Facing qibla'), findsOneWidget);
    expect(haptics.taps, 1);

    // Still aligned, so no second buzz.
    await _pushHeading(tester, controller, qibla + 2);
    await _pushHeading(tester, controller, qibla - 3);
    expect(find.text('Facing qibla'), findsOneWidget);
    expect(haptics.taps, 1);
  });

  testWidgets('alignment holds through jitter past the entry band', (
    tester,
  ) async {
    final haptics = RecordingQiblaHaptics();
    final qibla = _jakartaQibla();
    final controller = StreamController<CompassReading>.broadcast();
    addTearDown(controller.close);

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: controller.stream,
      haptics: haptics,
    );

    await _pushHeading(tester, controller, qibla);
    expect(find.text('Facing qibla'), findsOneWidget);

    // Outside the 5 degree entry band, inside the 8 degree exit band.
    await _pushHeading(tester, controller, qibla + 7);
    expect(find.text('Facing qibla'), findsOneWidget);
    expect(haptics.taps, 1);

    await _pushHeading(tester, controller, qibla + 40);
    expect(find.text('Facing qibla'), findsNothing);
    expect(find.text('Turn until the needle points up'), findsOneWidget);

    await _pushHeading(tester, controller, qibla + 1);
    expect(find.text('Facing qibla'), findsOneWidget);
    expect(haptics.taps, 2);
  });

  testWidgets('no haptic while the app is not in the foreground', (
    tester,
  ) async {
    final haptics = RecordingQiblaHaptics();
    final qibla = _jakartaQibla();
    final controller = StreamController<CompassReading>.broadcast();
    addTearDown(controller.close);

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: controller.stream,
      haptics: haptics,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pump();

    await _pushHeading(tester, controller, qibla);

    // The needle still turns; only the buzz waits for the foreground.
    expect(find.text('Facing qibla'), findsOneWidget);
    expect(haptics.taps, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pushHeading(tester, controller, qibla + 30);
    await _pushHeading(tester, controller, qibla);
    expect(haptics.taps, 1);
  });

  testWidgets('low accuracy shows a dismissible hint and keeps the needle', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 10, accuracyDeg: 45),
      ),
    );

    expect(
      find.byKey(const ValueKey('qibla_calibration_notice')),
      findsOneWidget,
    );
    expect(find.byType(QiblaCompassDial), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('qibla_calibration_dismiss')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('qibla_calibration_notice')),
      findsNothing,
    );
    expect(find.byType(QiblaCompassDial), findsOneWidget);
  });

  testWidgets('good accuracy and unknown accuracy show no calibration hint', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 10, accuracyDeg: 15),
      ),
    );
    expect(
      find.byKey(const ValueKey('qibla_calibration_notice')),
      findsNothing,
    );

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 10),
      ),
    );
    expect(
      find.byKey(const ValueKey('qibla_calibration_notice')),
      findsNothing,
    );
    expect(find.byType(QiblaCompassDial), findsOneWidget);
  });

  testWidgets('no magnetometer keeps the bearing and hides the dial', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.unavailable(),
      ),
    );

    expect(find.byType(QiblaCompassDial), findsNothing);
    expect(find.byKey(const ValueKey('qibla_no_compass')), findsOneWidget);
    expect(find.text('Live compass unavailable'), findsOneWidget);
    final bearingText = tester
        .widget<Text>(find.byKey(const ValueKey('qibla_bearing_label')))
        .data!;
    expect(bearingText, contains('WNW'));
    expect(find.text('Clockwise from true north'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('sensors that never deliver a heading fall back, not spin', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(const CompassReading.probing()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('qibla_no_compass')), findsNothing);

    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('qibla_no_compass')), findsOneWidget);
  });

  testWidgets('unknown city without GPS prompts a manual location', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: PrayerPrefs.defaults.copyWith(city: 'Atlantis', country: 'Ocean'),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 0),
      ),
    );

    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('Choose location'), findsOneWidget);
    expect(
      find.textContaining('Location permission may be denied'),
      findsOneWidget,
    );
    expect(find.text('Nearby mosques'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('unreadable prefs prompt a manual location, not a spinner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPrefsStoreProvider.overrideWithValue(_BrokenPrefsStore()),
          compassHeadingSourceProvider.overrideWithValue(
            StreamCompassHeadingSource(
              Stream<CompassReading>.value(const CompassReading.unavailable()),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QiblaPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Settings could not be read'), findsOneWidget);
    expect(find.text('Choose location'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('opening Qibla warms the nearby-mosque cache', (tester) async {
    final cache = MemoryMosqueCacheStore();
    var calls = 0;

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 0),
      ),
      mosqueCache: cache,
      mosqueHttp: MockClient((_) async {
        calls++;
        return http.Response(
          '{"elements":[{"type":"node","id":11,"lat":-6.21,"lon":106.845,'
          '"tags":{"amenity":"place_of_worship","religion":"muslim",'
          '"name":"Masjid Istiqlal"}}]}',
          200,
        );
      }),
    );

    expect(calls, greaterThan(0));
    final cached = await cache.read(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
    );
    expect(cached, isNotNull);
    expect(cached!.mosques.single.name, 'Masjid Istiqlal');
  });

  testWidgets('a warm cache means the prefetch touches no network', (
    tester,
  ) async {
    final cache = MemoryMosqueCacheStore();
    await cache.write(
      mosqueCacheKey(latitude: _jakartaLat, longitude: _jakartaLng),
      MosqueCacheEntry(
        mosques: const [
          NearbyMosque(
            id: 'node:1',
            name: 'Masjid Tersimpan',
            kind: NearbyMosqueKind.mosque,
            latitude: -6.21,
            longitude: 106.845,
            distanceMeters: 0,
            bearingDegrees: 0,
          ),
        ],
        radiusMeters: 2000,
        fetchedAt: DateTime.now(),
      ),
    );
    var calls = 0;

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.live(headingDeg: 0),
      ),
      mosqueCache: cache,
      mosqueHttp: MockClient((_) async {
        calls++;
        return http.Response('{"elements":[]}', 200);
      }),
    );

    expect(calls, 0);
  });

  testWidgets('Indonesian copy for alignment and missing compass', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        CompassReading.live(headingDeg: _jakartaQibla()),
      ),
      locale: const Locale('id'),
    );
    expect(find.text('Menghadap kiblat'), findsOneWidget);

    await _pumpQibla(
      tester,
      prefs: _jakartaPrefs(),
      readings: Stream<CompassReading>.value(
        const CompassReading.unavailable(),
      ),
      locale: const Locale('id'),
    );
    expect(find.text('Kompas langsung tidak tersedia'), findsOneWidget);
    final bearingText = tester
        .widget<Text>(find.byKey(const ValueKey('qibla_bearing_label')))
        .data!;
    expect(bearingText, contains('BBL'));
  });
}

final class _BrokenPrefsStore implements PrayerPrefsStore {
  @override
  Future<PrayerPrefs> read() async => throw StateError('prefs unreadable');

  @override
  Future<void> write(PrayerPrefs prefs) async {}
}
