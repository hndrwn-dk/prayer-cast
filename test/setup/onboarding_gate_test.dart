import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';

void main() {
  testWidgets('fresh install opens the audio step, not home', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(database: db, onboarding: store),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsOneWidget,
    );
    expect(find.text('ADZAN BERIKUTNYA'), findsNothing);
    expect(await store.read(), isNot(OnboardingRecord.notStarted));
    expect((await store.read()).step, OnboardingStep.audio);
  });

  testWidgets('configured install opens home and marks onboarding completed', (
    tester,
  ) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        onboarding: store,
        prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsNothing,
    );
    expect((await store.read()).step, OnboardingStep.completed);
    // Home fade-ins schedule short timers. Advance past them so the
    // test binding does not fail on a pending timer at dispose.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('audio phone choice shows the phone step', (tester) async {
    final store = MemoryOnboardingStore();
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          prayerPrefsStoreProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          locale: Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingGate(home: Text('HOME')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('onboarding_audio_phone')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('onboarding_phone_adhan')),
      findsOneWidget,
    );
  });
}
