import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/kemenag_client.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';
import 'package:prayer_cast/setup/ui/onboarding_prayer_step.dart';

final _offlineHttp = MockClient((request) async => http.Response('nope', 500));

class _FakeLocationResolver implements LocationResolving {
  _FakeLocationResolver({
    this.granted = true,
    this.result = const ResolvedLocation(
      latitude: 1.3,
      longitude: 103.8,
      city: 'Singapore',
      country: 'Singapore',
    ),
    this.error,
  });

  final bool granted;
  final ResolvedLocation result;
  final Object? error;
  var resolveCalls = 0;

  @override
  Future<bool> hasGrantedPermission() async => granted;

  @override
  Future<ResolvedLocation> resolveCurrent() async {
    resolveCalls += 1;
    final err = error;
    if (err != null) throw err;
    return result;
  }
}

void main() {
  Future<void> pumpPrayerStep(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    required MemoryPrayerPrefsStore prefs,
    required LocationResolving resolver,
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
          home: OnboardingPrayerStep(
            record: await store.read(),
            locationResolver: resolver,
          ),
        ),
      ),
    );
    await tester.pump();
  }

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

  testWidgets('location success shows result then swipe advances', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    final resolver = _FakeLocationResolver();
    await pumpPrayerStep(
      tester,
      store: store,
      prefs: prefs,
      resolver: resolver,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(resolver.resolveCalls, 1);
    final saved = await prefs.read();
    expect(saved.configured, isTrue);
    expect(saved.city, 'Singapore');
    expect(saved.country, 'Singapore');
    expect(find.textContaining('Singapore'), findsWidgets);
    expect(find.byKey(const ValueKey('onboarding_prayer_retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_swipe_hint')), findsOneWidget);
    expect((await store.read()).step, OnboardingStep.prayer);

    await tester.tap(find.byKey(const ValueKey('onboarding_swipe_hint')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect((await store.read()).step, OnboardingStep.notifications);
    expect((await store.read()).back, OnboardingStep.prayer);
  });

  testWidgets('location failure stays on prayer with an error', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    final resolver = _FakeLocationResolver(
      error: const LocationResolveFailure(LocationResolveCode.denied),
    );
    await pumpPrayerStep(
      tester,
      store: store,
      prefs: prefs,
      resolver: resolver,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await prefs.read()).configured, isFalse);
    expect(find.textContaining('lokasi'), findsWidgets);
  });

  testWidgets('indonesia fix selects Kemenag method', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.speaker));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    final resolver = _FakeLocationResolver(
      result: const ResolvedLocation(
        latitude: -6.2,
        longitude: 106.8,
        city: 'Jakarta',
        country: 'Indonesia',
      ),
    );
    await pumpPrayerStep(
      tester,
      store: store,
      prefs: prefs,
      resolver: resolver,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = await prefs.read();
    expect(saved.methodId, -1);
    expect(saved.city, 'Jakarta');
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

  testWidgets('gate shows the prayer title and location action', (tester) async {
    final store = MemoryOnboardingStore(prayerRecord(OnboardingStep.phone));
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);
    await pumpPrayerGate(tester, store: store, prefs: prefs);

    expect(find.text('Atur waktu sholat'), findsOneWidget);
    expect(find.text('Gunakan lokasi saat ini'), findsOneWidget);
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
    expect(find.text('Use current location'), findsOneWidget);
  });
}
