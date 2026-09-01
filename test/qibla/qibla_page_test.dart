import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/qibla/compass_heading.dart';
import 'package:prayer_cast/qibla/qibla_bearing.dart';
import 'package:prayer_cast/qibla/qibla_providers.dart';
import 'package:prayer_cast/qibla/ui/qibla_page.dart';

Future<void> _pumpQibla(
  WidgetTester tester, {
  required PrayerPrefs prefs,
  required Stream<double?> heading,
  Locale locale = const Locale('en'),
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
          StreamCompassHeadingSource(heading),
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

void main() {
  testWidgets('shows Jakarta bearing and nearby-mosques action', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: PrayerPrefs.defaults.copyWith(
        city: 'Jakarta',
        country: 'Indonesia',
        latitude: -6.2088,
        longitude: 106.8456,
        configured: true,
      ),
      heading: Stream<double?>.value(0),
    );

    expect(find.text('Qibla'), findsOneWidget);
    expect(find.byKey(const ValueKey('qibla_bearing_label')), findsOneWidget);
    final bearingText = tester
        .widget<Text>(find.byKey(const ValueKey('qibla_bearing_label')))
        .data!;
    expect(bearingText, contains('NW'));
    expect(find.text('Nearby mosques'), findsOneWidget);
    expect(find.text('Facing Qibla'), findsNothing);
    expect(find.text('Turn until the needle points up'), findsOneWidget);
  });

  testWidgets('aligned heading shows facing copy', (tester) async {
    const lat = -6.2088;
    const lng = 106.8456;
    final qibla = qiblaBearingDegrees(latitude: lat, longitude: lng);
    await _pumpQibla(
      tester,
      prefs: PrayerPrefs.defaults.copyWith(
        city: 'Jakarta',
        country: 'Indonesia',
        latitude: lat,
        longitude: lng,
        configured: true,
      ),
      heading: Stream<double?>.value(qibla),
    );

    expect(find.text('Facing Qibla'), findsOneWidget);
  });

  testWidgets('unknown city without GPS asks to set prayer times', (
    tester,
  ) async {
    await _pumpQibla(
      tester,
      prefs: PrayerPrefs.defaults.copyWith(city: 'Atlantis', country: 'Ocean'),
      heading: Stream<double?>.value(0),
    );

    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('Open Prayer times'), findsOneWidget);
    expect(find.text('Nearby mosques'), findsNothing);
  });
}
