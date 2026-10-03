import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/kemenag_client.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';

final _offlineHttp = MockClient((request) async => http.Response('nope', 500));

void main() {
  Future<void> pumpPrayerGate(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    required MemoryPrayerPrefsStore prefs,
    Locale locale = const Locale('id'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          prayerPrefsStoreProvider.overrideWithValue(prefs),
          adhanNextPrayerProvider.overrideWithValue(
            AdhanNextPrayerProvider(
              store: prefs,
              client: AladhanClient(httpClient: _offlineHttp),
              kemenagClient: KemenagClient(httpClient: _offlineHttp),
            ),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const OnboardingGate(home: Text('HOME')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  OnboardingRecord prayerRecord(OnboardingStep back) {
    return OnboardingRecord(step: OnboardingStep.prayer, back: back);
  }

  testWidgets('stays on prayer when settings return unconfigured', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await prefs.read()).configured, isFalse);
  });

  testWidgets('advances to notifications when prayer times are configured', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.speaker));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
    await tester.pumpAndSettle();
    final current = await prefs.read();
    await prefs.write(current.copyWith(configured: true));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect((await store.read()).step, OnboardingStep.notifications);
    expect((await store.read()).back, OnboardingStep.prayer);
  });

  testWidgets('back returns to the phone step', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.phone);
    expect((await store.read()).back, isNull);
  });

  testWidgets('back returns to the speaker step', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.speaker));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.speaker);
    expect((await store.read()).back, isNull);
  });

  testWidgets('gate shows the prayer title and action', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    expect(find.text('Atur waktu sholat'), findsOneWidget);
    expect(find.text('Pilih kota dan metode'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsNothing,
    );
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('english copy names the prayer step', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(
      tester,
      store: store,
      prefs: prefs,
      locale: const Locale('en'),
    );

    expect(find.text('Set prayer times'), findsOneWidget);
    expect(find.text('Choose city and method'), findsOneWidget);
  });
}
