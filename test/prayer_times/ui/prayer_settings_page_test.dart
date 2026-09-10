import 'dart:async';
import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/prayer_times/ui/location_disclosure.dart';
import 'package:prayer_cast/prayer_times/ui/notification_disclosure.dart';
import 'package:prayer_cast/prayer_times/ui/prayer_settings_page.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:prayer_cast/support/open_support_url.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required PrayerDeliveryMode mode,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.light(),
        home: Scaffold(
          body: PrayerScheduleTile(
            prayer: NextPrayer(
              name: 'fajr',
              scheduledAt: DateTime(2026, 8, 13, 5, 32),
              voiceId: 'fajr_adhan',
            ),
            voiceId: 'fajr_adhan',
            deliveryMode: mode,
            castVolume: null,
            testing: false,
            enabled: true,
            onVoiceChanged: (_) {},
            onDeliveryChanged: (_) {},
            onVolumeChanged: (_) {},
            onTest: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('schedule row shows delivery control defaulting to Cast', (
    tester,
  ) async {
    await pumpTile(tester, mode: PrayerDeliveryMode.cast);
    expect(find.byKey(const ValueKey('delivery-fajr-cast')), findsOneWidget);
    expect(find.text('Cast'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-fajr-fajr_adhan')), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-icon-fajr')), findsOneWidget);
  });

  testWidgets('beep mode hides the voice dropdown', (tester) async {
    await pumpTile(tester, mode: PrayerDeliveryMode.beep);
    expect(find.byKey(const ValueKey('delivery-fajr-beep')), findsOneWidget);
    expect(find.text('Beep on phone'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-fajr-fajr_adhan')), findsNothing);
  });

  testWidgets('page has no Default delivery control', (tester) async {
    await _pumpSettings(tester);
    expect(find.text('Default delivery'), findsNothing);
    expect(find.text('Default pengiriman'), findsNothing);
  });

  testWidgets('cast fallback toggle persists off', (tester) async {
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        defaultsMigrated: true,
        castFallbackToPhone: true,
        deliveryByPrayer: {
          'fajr': 'cast',
          'dhuhr': 'cast',
          'asr': 'cast',
          'maghrib': 'cast',
          'isha': 'cast',
        },
      ),
    );
    final engine = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async => http.Response('nope', 500)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPrefsStoreProvider.overrideWithValue(store),
          adhanNextPrayerProvider.overrideWithValue(engine),
          localPrayerPlayerProvider.overrideWithValue(
            const SilentLocalPrayerPlayer(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PrayerCastTheme.light(),
          home: const PrayerSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final toggle = find.byKey(const ValueKey('cast-fallback-switch-true'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: _settingsScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(toggle),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('cast-fallback-switch-false')),
      findsOneWidget,
    );
    expect((await store.read()).castFallbackToPhone, isFalse);
  });

  testWidgets('cast fallback card hidden when no prayer uses Cast', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      prefs: PrayerPrefs.defaults.copyWith(
        city: 'Singapore',
        country: 'Singapore',
        configured: true,
        defaultsMigrated: true,
        deliveryByPrayer: {
          for (final p in PrayerPrefs.prayerKeys) p: 'adhanPhone',
        },
      ),
    );
    expect(find.text('If the speaker is unavailable'), findsNothing);
  });

  testWidgets('pre-prayer reminder minutes and sound can be changed', (
    tester,
  ) async {
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        defaultsMigrated: true,
        prePrayerAlertMinutes: 0,
        prePrayerAlertSound: PrePrayerAlertSound.shortBeep,
      ),
    );
    final engine = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient((request) async => http.Response('nope', 500)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPrefsStoreProvider.overrideWithValue(store),
          adhanNextPrayerProvider.overrideWithValue(engine),
          localPrayerPlayerProvider.overrideWithValue(
            const SilentLocalPrayerPlayer(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PrayerCastTheme.light(),
          home: const PrayerSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final minutesField = find.byKey(const ValueKey('pre-prayer-minutes-0'));
    await tester.scrollUntilVisible(
      minutesField,
      300,
      scrollable: _settingsScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(minutesField),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(minutesField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byKey(const ValueKey('pre-prayer-minutes-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('pre-prayer-sound-shortBeep')), findsOneWidget);

    final soundField = find.byKey(const ValueKey('pre-prayer-sound-shortBeep'));
    await Scrollable.ensureVisible(
      tester.element(soundField),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(soundField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long beep').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byKey(const ValueKey('pre-prayer-sound-longBeep')), findsOneWidget);
    final saved = await store.read();
    expect(saved.prePrayerAlertMinutes, 10);
    expect(saved.prePrayerAlertSound, PrePrayerAlertSound.longBeep);
  });

  testWidgets('per-prayer delivery sheet can select Adhan on phone', (
    tester,
  ) async {
    PrayerDeliveryMode? chosen;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.light(),
        home: Scaffold(
          body: PrayerScheduleTile(
            prayer: NextPrayer(
              name: 'fajr',
              scheduledAt: DateTime(2026, 8, 13, 5, 32),
              voiceId: 'fajr_adhan',
            ),
            voiceId: 'fajr_adhan',
            deliveryMode: PrayerDeliveryMode.cast,
            castVolume: null,
            testing: false,
            enabled: true,
            onVoiceChanged: (_) {},
            onDeliveryChanged: (mode) => chosen = mode,
            onVolumeChanged: (_) {},
            onTest: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delivery-fajr-cast')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adhan on phone'));
    await tester.pumpAndSettle();
    expect(chosen, PrayerDeliveryMode.adhanPhone);
  });

  testWidgets('changing Fajr delivery persists without Default delivery', (
    tester,
  ) async {
    const sampleBody = '''
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
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        defaultsMigrated: true,
        deliveryByPrayer: {
          'fajr': 'cast',
          'dhuhr': 'cast',
          'asr': 'cast',
          'maghrib': 'cast',
          'isha': 'cast',
        },
      ),
    );
    final engine = AdhanNextPrayerProvider(
      store: store,
      client: AladhanClient(
        httpClient: MockClient(
          (request) async => http.Response(sampleBody, 200),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPrefsStoreProvider.overrideWithValue(store),
          adhanNextPrayerProvider.overrideWithValue(engine),
          localPrayerPlayerProvider.overrideWithValue(
            const SilentLocalPrayerPlayer(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PrayerCastTheme.light(),
          home: const PrayerSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Default delivery'), findsNothing);
    final fajrDelivery = find.byKey(const ValueKey('delivery-fajr-cast'));
    await tester.scrollUntilVisible(
      fajrDelivery,
      300,
      scrollable: _settingsScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(fajrDelivery),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(fajrDelivery);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adhan on phone'));
    await tester.pumpAndSettle();
    // Autosave debounce is 500ms.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('delivery-fajr-adhanPhone')),
      findsOneWidget,
    );
    final saved = await store.read();
    expect(saved.deliveryFor('fajr'), PrayerDeliveryMode.adhanPhone);
    expect(saved.deliveryFor('dhuhr'), PrayerDeliveryMode.cast);
  });

  testWidgets('Test scheduled adhan is hidden for regular users', (
    tester,
  ) async {
    await _pumpSettings(tester);
    expect(find.text('Test scheduled adhan'), findsNothing);
    expect(find.byKey(const ValueKey('dry_run_toggle')), findsNothing);
  });

  testWidgets('notification disclosure copy is localized in Indonesian', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.forest(),
        home: const Scaffold(body: NotificationDisclosureDialog()),
      ),
    );
    await tester.pump();

    expect(find.text('Tampilkan notifikasi uji'), findsOneWidget);
    expect(find.text('Izinkan'), findsOneWidget);
    expect(find.text('Nanti saja'), findsOneWidget);
  });

  testWidgets('save without location shows status above Save, not a SnackBar', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      prefs: const PrayerPrefs(
        city: '',
        country: '',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: false,
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.byKey(const ValueKey('prayer_settings_status')),
      findsOneWidget,
    );
    expect(
      find.text('Use current location, or enter city and country first'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save button sits above the Android navigation inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 915);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await _pumpSettings(tester);

    final save = find.widgetWithText(FilledButton, 'Save');
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(915 - 48));
  });

  testWidgets('location disclosure appears before resolve when not granted', (
    tester,
  ) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsOneWidget);
    expect(find.text('Location is optional'), findsOneWidget);
    expect(find.textContaining('fill city and country'), findsOneWidget);
    expect(find.textContaining('not used to track you'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(resolver.resolveCalls, 0);

    final dialog = tester.widget<AlertDialog>(
      find.byKey(LocationDisclosureDialog.dialogKey),
    );
    expect(dialog.backgroundColor, PrayerCastColors.canopyDeep);
    expect(dialog.backgroundColor, isNot(PrayerCastColors.ink));
    expect(dialog.elevation, 12);
    final shape = dialog.shape as RoundedRectangleBorder;
    expect(shape.side.width, 1);
    expect(shape.side.color, PrayerCastColors.mist.withValues(alpha: 0.28));
    expect(
      tester.widget<Text>(find.text('Location is optional')).style?.color,
      PrayerCastColors.surfaceRaised,
    );
    expect(
      tester.widget<Text>(find.text('Type city instead')).style?.color,
      PrayerCastColors.mist,
    );
    expect(
      tester.widget<Text>(find.text('Privacy policy')).style?.color,
      PrayerCastColors.mist,
    );
  });

  testWidgets('location disclosure Continue then resolves city', (
    tester,
  ) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(LocationDisclosureDialog.continueKey),
    );
    await tester.tap(find.byKey(LocationDisclosureDialog.continueKey));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsNothing);
    expect(resolver.resolveCalls, 1);
    expect(find.text('Location: Jakarta, Indonesia'), findsOneWidget);
  });

  testWidgets('location disclosure Type city skips GPS and opens the form', (
    tester,
  ) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(LocationDisclosureDialog.typeCityKey),
    );
    await tester.tap(find.byKey(LocationDisclosureDialog.typeCityKey));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsNothing);
    expect(resolver.resolveCalls, 0);
    expect(find.text('Hide city form'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
  });

  testWidgets('already-granted location skips disclosure', (tester) async {
    final resolver = _FakeLocationResolver(granted: true);
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsNothing);
    expect(resolver.resolveCalls, 1);
    expect(find.text('Location: Jakarta, Indonesia'), findsOneWidget);
  });

  testWidgets('location disclosure privacy link opens the policy URL', (
    tester,
  ) async {
    final launched = <Uri>[];
    debugLaunchExternalUrl = (uri) async {
      launched.add(uri);
      return true;
    };
    addTearDown(() => debugLaunchExternalUrl = null);

    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.byKey(LocationDisclosureDialog.privacyKey));
    await tester.tap(find.byKey(LocationDisclosureDialog.privacyKey));
    await tester.pump();

    expect(launched, [Uri.parse(AppLinks.privacyPolicyUrl)]);
    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsOneWidget);
    expect(resolver.resolveCalls, 0);
  });

  testWidgets('location timeout shows l10n message, not TimeoutException', (
    tester,
  ) async {
    final resolver = _TimeoutLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(
      find.text(
        'Could not get your location in time. Try again, or enter city and country.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('location disclosure copy is localized in Indonesian', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.forest(),
        home: const Scaffold(body: LocationDisclosureDialog()),
      ),
    );
    await tester.pump();

    expect(find.text('Lokasi bersifat opsional'), findsOneWidget);
    expect(find.textContaining('mengisi kota dan negara'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('Ketik kota saja'), findsOneWidget);
    expect(find.text('Kebijakan privasi'), findsOneWidget);
  });
}

Finder _settingsScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('prayer_settings_list')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  PrayerPrefs? prefs,
  LocationResolving locationResolver = const LocationResolver(),
  Locale locale = const Locale('en'),
}) async {
  final store = MemoryPrayerPrefsStore(prefs ?? PrayerPrefs.defaults);
  final engine = AdhanNextPrayerProvider(
    store: store,
    client: AladhanClient(
      httpClient: MockClient((request) async => http.Response('nope', 500)),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerPrefsStoreProvider.overrideWithValue(store),
        adhanNextPrayerProvider.overrideWithValue(engine),
        localPrayerPlayerProvider.overrideWithValue(
          const SilentLocalPrayerPlayer(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.light(),
        home: PrayerSettingsPage(
          locationResolver: locationResolver,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

final class _TimeoutLocationResolver implements LocationResolving {
  @override
  Future<bool> hasGrantedPermission() async => true;

  @override
  Future<ResolvedLocation> resolveCurrent() async {
    throw TimeoutException('Future not completed', const Duration(seconds: 20));
  }
}

final class _FakeLocationResolver implements LocationResolving {
  _FakeLocationResolver({this.granted = false});

  final bool granted;
  int resolveCalls = 0;

  @override
  Future<bool> hasGrantedPermission() async => granted;

  @override
  Future<ResolvedLocation> resolveCurrent() async {
    resolveCalls++;
    return const ResolvedLocation(
      latitude: -6.2,
      longitude: 106.8,
      city: 'Jakarta',
      country: 'Indonesia',
    );
  }
}
