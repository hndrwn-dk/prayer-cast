import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/setup_checklist_card.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/setup_card_store.dart';

import '../delivery/cast_client_test.dart';
import '../presence/fake_mdns_browser.dart';

HomeOnboarding _onboarding({String? homeCastId, String? friendlyName}) {
  final store = MemoryFingerprintStore(
    homeCastId: homeCastId,
    homeCastFriendlyName: friendlyName,
  );
  return HomeOnboarding(
    castPlatform: FakeCastPlatform(devices: const []),
    store: store,
    lanFingerprint: LanFingerprint(
      browser: FakeMdnsBrowser(const []),
      store: store,
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required MemorySetupCardStore setupStore,
  required MemoryPrayerPrefsStore prefsStore,
  HomeOnboarding? onboarding,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setupCardStoreProvider.overrideWithValue(setupStore),
        prayerPrefsStoreProvider.overrideWithValue(prefsStore),
        homeOnboardingProvider.overrideWithValue(onboarding ?? _onboarding()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.forest(),
        home: Scaffold(
          body: SetupChecklistCard(
            onOpenSpeaker: () {},
            onOpenPrayerTimes: () {},
            onOpenDelivery: () {},
            onOpenReminders: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('hidden when prayer already configured on first read', (
    tester,
  ) async {
    final setup = MemorySetupCardStore();
    final prefs = MemoryPrayerPrefsStore(
      PrayerPrefs.defaults.copyWith(configured: true),
    );

    await _pumpCard(tester, setupStore: setup, prefsStore: prefs);

    expect(find.byKey(SetupChecklistCard.keyName), findsNothing);
    expect(find.byKey(SetupChecklistCard.speakerKey), findsNothing);
    expect(find.byKey(SetupChecklistCard.prayerKey), findsNothing);
    final flags = await setup.read();
    expect(flags.dismissed, isTrue);
    expect(flags.existingUserMigrated, isTrue);
  });

  testWidgets('shown for unconfigured prefs', (tester) async {
    final setup = MemorySetupCardStore();
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await _pumpCard(tester, setupStore: setup, prefsStore: prefs);

    expect(find.byKey(SetupChecklistCard.keyName), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.dismissKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.speakerKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.noSpeakerKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.prayerKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.remindersKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.deliveryKey), findsNothing);
    final flags = await setup.read();
    expect(flags.dismissed, isFalse);
    expect(flags.existingUserMigrated, isTrue);
  });

  testWidgets('dismiss hides after restart', (tester) async {
    final setup = MemorySetupCardStore();
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await _pumpCard(tester, setupStore: setup, prefsStore: prefs);
    expect(find.byKey(SetupChecklistCard.keyName), findsOneWidget);

    await tester.tap(find.byKey(SetupChecklistCard.dismissKey));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(SetupChecklistCard.keyName), findsNothing);

    await _pumpCard(tester, setupStore: setup, prefsStore: prefs);
    expect(find.byKey(SetupChecklistCard.keyName), findsNothing);
    expect((await setup.read()).dismissed, isTrue);
  });

  testWidgets('Use this phone reveals delivery row', (tester) async {
    final setup = MemorySetupCardStore();
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await _pumpCard(tester, setupStore: setup, prefsStore: prefs);
    expect(find.byKey(SetupChecklistCard.keyName), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.deliveryKey), findsNothing);

    await tester.tap(find.byKey(SetupChecklistCard.noSpeakerKey));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(SetupChecklistCard.deliveryKey), findsOneWidget);
    expect(find.text('Adhan on this phone'), findsOneWidget);
    expect((await setup.read()).noSpeaker, isTrue);
  });

  testWidgets('saved speaker hides delivery row', (tester) async {
    final setup = MemorySetupCardStore();
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await _pumpCard(
      tester,
      setupStore: setup,
      prefsStore: prefs,
      onboarding: _onboarding(homeCastId: 'nest-1', friendlyName: 'Kitchen'),
    );

    expect(find.byKey(SetupChecklistCard.keyName), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.speakerKey), findsOneWidget);
    expect(find.byKey(SetupChecklistCard.deliveryKey), findsNothing);
    expect(find.text('Adhan on this phone'), findsNothing);
  });

  testWidgets('delivery row ticks for saved phone adhan, beep, or takbir', (
    tester,
  ) async {
    final tick = find.descendant(
      of: find.byKey(SetupChecklistCard.deliveryKey),
      matching: find.byType(CustomPaint),
    );

    Future<void> pumpMode(PrayerDeliveryMode mode) {
      return _pumpCard(
        tester,
        setupStore: MemorySetupCardStore(
          const SetupCardFlags(noSpeaker: true, existingUserMigrated: true),
        ),
        prefsStore: MemoryPrayerPrefsStore(
          PrayerPrefs.defaults.copyWith(defaultDeliveryMode: mode),
        ),
      );
    }

    await pumpMode(PrayerDeliveryMode.cast);
    expect(find.byKey(SetupChecklistCard.deliveryKey), findsOneWidget);
    expect(tick, findsNothing);

    for (final mode in const [
      PrayerDeliveryMode.adhanPhone,
      PrayerDeliveryMode.beep,
      PrayerDeliveryMode.takbir,
    ]) {
      await pumpMode(mode);
      expect(tick, findsOneWidget);
    }

    await _pumpCard(
      tester,
      setupStore: MemorySetupCardStore(
        const SetupCardFlags(noSpeaker: true, existingUserMigrated: true),
      ),
      prefsStore: MemoryPrayerPrefsStore(
        PrayerPrefs.defaults.copyWith(
          defaultDeliveryMode: PrayerDeliveryMode.cast,
          deliveryByPrayer: const {'fajr': 'adhanPhone'},
        ),
      ),
    );
    expect(tick, findsOneWidget);
  });
}
