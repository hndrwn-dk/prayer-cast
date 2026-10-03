import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';
import 'package:prayer_cast/setup/ui/onboarding_phone_step.dart';

void main() {
  Future<void> pumpPhoneStep(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    required MemoryPrayerPrefsStore prefs,
  }) async {
    final record = await store.read();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          prayerPrefsStoreProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingPhoneStep(record: record),
        ),
      ),
    );
  }

  OnboardingRecord phoneRecord() {
    return const OnboardingRecord(
      step: OnboardingStep.phone,
      back: OnboardingStep.audio,
    );
  }

  testWidgets('adhan choice saves adhan and advances to prayer', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(phoneRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPhoneStep(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_phone_adhan')));
    await tester.pump();

    expect(
      (await prefs.read()).defaultDeliveryMode,
      PrayerDeliveryMode.adhanPhone,
    );
    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await store.read()).back, OnboardingStep.phone);
  });

  testWidgets('beep choice saves beep and advances to prayer', (tester) async {
    final store = MemoryOnboardingStore(phoneRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPhoneStep(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_phone_beep')));
    await tester.pump();

    expect((await prefs.read()).defaultDeliveryMode, PrayerDeliveryMode.beep);
    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await store.read()).back, OnboardingStep.phone);
  });

  testWidgets('does not offer takbir on this phone', (tester) async {
    final store = MemoryOnboardingStore(phoneRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPhoneStep(tester, store: store, prefs: prefs);

    expect(find.text('Takbir di HP'), findsNothing);
    expect(find.text('Adzan di HP'), findsOneWidget);
    expect(find.text('Beep di HP'), findsOneWidget);
    expect(find.text('HP ini memutarnya bagaimana?'), findsOneWidget);
  });

  testWidgets('back returns to the audio step', (tester) async {
    final store = MemoryOnboardingStore(phoneRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPhoneStep(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.audio);
    expect((await store.read()).back, isNull);
  });

  testWidgets('gate renders the phone step for a phone record', (tester) async {
    final store = MemoryOnboardingStore(phoneRecord());
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

    expect(
      find.byKey(const ValueKey('onboarding_phone_adhan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsNothing,
    );
    expect(find.text('HOME'), findsNothing);
  });
}
