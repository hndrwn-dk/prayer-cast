import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_audio_loader.dart';
import 'package:prayer_cast/home_delivery/coordinator/delivery_settings.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_orchestrator.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/platform/device_conditions.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/prayer_times/ui/location_disclosure.dart';
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
            testing: false,
            enabled: true,
            onVoiceChanged: (_) {},
            onDeliveryChanged: (_) {},
            onTest: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('schedule row shows delivery control defaulting to Cast',
      (tester) async {
    await pumpTile(tester, mode: PrayerDeliveryMode.cast);
    expect(find.byKey(const ValueKey('delivery-fajr-cast')), findsOneWidget);
    expect(find.text('Cast'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-fajr-fajr_adhan')), findsOneWidget);
  });

  testWidgets('beep mode hides the voice dropdown', (tester) async {
    await pumpTile(tester, mode: PrayerDeliveryMode.beep);
    expect(find.byKey(const ValueKey('delivery-fajr-beep')), findsOneWidget);
    expect(find.text('Beep on phone'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-fajr-fajr_adhan')), findsNothing);
  });

  testWidgets('dry-run offers 1 and 5 minutes only', (tester) async {
    await _pumpSettings(tester);
    final dryRun = find.byKey(const ValueKey('dry_run_1m'));
    await tester.scrollUntilVisible(
      dryRun,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('prayer_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(dryRun);
    await tester.pump();

    expect(find.text('In 1 minute'), findsOneWidget);
    expect(find.text('In 5 minutes'), findsOneWidget);
    expect(find.text('In 10 minutes'), findsNothing);
    expect(find.text('In 1 hour'), findsNothing);
    expect(find.byKey(const ValueKey('dry_run_1m')), findsOneWidget);
    expect(find.byKey(const ValueKey('dry_run_5m')), findsOneWidget);
    expect(find.byKey(const ValueKey('dry_run_10m')), findsNothing);
    expect(find.byKey(const ValueKey('dry_run_1h')), findsNothing);
  });

  testWidgets('dry-run buttons are localized in Indonesian', (tester) async {
    await _pumpSettings(tester, locale: const Locale('id'));
    final dryRun = find.byKey(const ValueKey('dry_run_1m'));
    await tester.scrollUntilVisible(
      dryRun,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('prayer_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(dryRun);
    await tester.pump();

    expect(find.text('Dalam 1 menit'), findsOneWidget);
    expect(find.text('Dalam 5 menit'), findsOneWidget);
    expect(find.text('Dalam 10 menit'), findsNothing);
    expect(find.text('Dalam 1 jam'), findsNothing);
  });

  testWidgets('dry-run shows inline time, not a SnackBar', (tester) async {
    final alarm = _FakeExactAlarm();
    addTearDown(alarm.dispose);
    final t0 = DateTime(2026, 8, 13, 20, 35);
    final coordinator = _coordinator(
      alarm: alarm,
      clock: FakeClock(t0),
      next: NextPrayer(
        name: 'isha',
        scheduledAt: t0.add(const Duration(hours: 2)),
        voiceId: 'standard_adhan',
      ),
    );
    await coordinator.start();

    await _pumpSettings(tester, coordinator: coordinator);
    final dryRun = find.byKey(const ValueKey('dry_run_5m'));
    await tester.scrollUntilVisible(
      dryRun,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('prayer_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(dryRun);
    await tester.pump();
    await tester.tap(dryRun);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const ValueKey('dry_run_status')), findsOneWidget);
    expect(find.text('Test adhan at 20:40'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsWidgets);
  });

  testWidgets('dry-run failure stays on the card, not a SnackBar',
      (tester) async {
    final alarm = _FakeExactAlarm();
    addTearDown(alarm.dispose);
    final coordinator = _coordinator(
      alarm: alarm,
      clock: FakeClock(DateTime(2026, 8, 13, 20, 35)),
      next: NextPrayer(
        name: 'isha',
        scheduledAt: DateTime(2026, 8, 13, 22, 0),
        voiceId: 'standard_adhan',
      ),
    );

    await _pumpSettings(tester, coordinator: coordinator);
    final dryRun = find.byKey(const ValueKey('dry_run_5m'));
    await tester.scrollUntilVisible(
      dryRun,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('prayer_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(dryRun);
    await tester.pump();
    await tester.tap(dryRun);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const ValueKey('dry_run_status')), findsOneWidget);
    expect(
      find.textContaining('Could not schedule test adhan'),
      findsOneWidget,
    );
  });

  testWidgets('save without location shows status above Save, not a SnackBar',
      (tester) async {
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
    expect(find.byKey(const ValueKey('prayer_settings_status')), findsOneWidget);
    expect(
      find.text('Use current location, or enter city and country first'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('location disclosure appears before resolve when not granted',
      (tester) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsOneWidget);
    expect(find.text('Location is optional'), findsOneWidget);
    expect(find.textContaining('GPS is optional'), findsOneWidget);
    expect(
      find.textContaining('not used to decide whether you are home'),
      findsOneWidget,
    );
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
    expect(
      shape.side.color,
      PrayerCastColors.mist.withValues(alpha: 0.28),
    );
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

  testWidgets('location disclosure Continue then resolves city', (tester) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.byKey(LocationDisclosureDialog.continueKey));
    await tester.tap(find.byKey(LocationDisclosureDialog.continueKey));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(LocationDisclosureDialog.dialogKey), findsNothing);
    expect(resolver.resolveCalls, 1);
    expect(find.text('Location: Jakarta, Indonesia'), findsOneWidget);
  });

  testWidgets('location disclosure Type city skips GPS and opens the form',
      (tester) async {
    final resolver = _FakeLocationResolver();
    await _pumpSettings(tester, locationResolver: resolver);

    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.byKey(LocationDisclosureDialog.typeCityKey));
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

  testWidgets('location disclosure privacy link opens the policy URL',
      (tester) async {
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

  testWidgets('location disclosure copy is localized in Indonesian',
      (tester) async {
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
    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('Ketik kota saja'), findsOneWidget);
    expect(find.text('Kebijakan privasi'), findsOneWidget);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  PrayerDeliveryCoordinator? coordinator,
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
          coordinator: coordinator,
          locationResolver: locationResolver,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

PrayerDeliveryCoordinator _coordinator({
  required _FakeExactAlarm alarm,
  required FakeClock clock,
  required NextPrayer next,
}) {
  return PrayerDeliveryCoordinator(
    exactAlarm: alarm,
    nextPrayer: _FixedNextPrayer(next),
    deviceConditions: _FakeConditions(),
    settings: _FakeSettings(),
    audioLoader: _FakeAudio(),
    runDelivery: (request) async => const DeliveryAttemptResult(
      sessionId: 'sess',
      outcome: Outcome.played,
      role: 'SOLO',
    ),
    clock: clock,
  );
}

final class _FixedNextPrayer implements NextPrayerProvider {
  _FixedNextPrayer(this.prayer);
  final NextPrayer prayer;

  @override
  Future<NextPrayer> next({required DateTime after}) async => prayer;
}

final class _FakeExactAlarm implements ExactAlarmPlatform {
  final _fireController = StreamController<AlarmFiredEvent>.broadcast();

  @override
  Stream<AlarmFiredEvent> get onFired => _fireController.stream;

  @override
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> stopForegroundService() async {}

  @override
  Future<ScheduledAlarm?> readScheduled() async => null;

  Future<void> dispose() => _fireController.close();
}

final class _FakeSettings implements DeliverySettings {
  @override
  Future<String?> homeCastDeviceId() async => 'cast-home-1';

  @override
  Future<double> playbackVolume() async => 0.7;
}

final class _FakeAudio implements AdzanAudioLoader {
  @override
  Future<AdzanAudioData> load(String voiceId) async => AdzanAudioData(
        bytes: Uint8List.fromList(List<int>.filled(32, 1)),
        contentType: 'audio/mpeg',
        extension: 'mp3',
      );
}

final class _FakeConditions implements DeviceConditionsProvider {
  @override
  Future<DeviceConditions> current() async => const DeviceConditions(
        formFactor: DeviceFormFactor.phone,
        isPluggedIn: true,
        isScreenOn: true,
        batteryPercent: 80,
        batterySaverActive: false,
        clockSkewDetected: false,
      );
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
