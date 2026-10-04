import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';

void main() {
  Future<void> pumpSpeakerGate(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    required MemoryPrayerPrefsStore prefs,
    required List<Override> overrides,
    SpeakerScanResult discovery = const SpeakerScanResult(devices: []),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          prayerPrefsStoreProvider.overrideWithValue(prefs),
          batteryUnrestrictedProvider.overrideWith((ref) async => true),
          speakerDiscoveryProvider.overrideWith((ref) async => discovery),
          ...overrides,
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
  }

  OnboardingRecord speakerRecord() {
    return const OnboardingRecord(
      step: OnboardingStep.speaker,
      back: OnboardingStep.audio,
    );
  }

  testWidgets('saved speaker advances to prayer as cast', (tester) async {
    final store = MemoryOnboardingStore(speakerRecord());
    final prefs = MemoryPrayerPrefsStore(
      PrayerPrefs.defaults.copyWith(
        defaultDeliveryMode: PrayerDeliveryMode.beep,
      ),
    );
    final speakerTick = StateProvider<int>((ref) => 0);

    await pumpSpeakerGate(
      tester,
      store: store,
      prefs: prefs,
      discovery: SpeakerScanResult(
        devices: [
          CastReceiver(
            deviceId: 'nest-1',
            friendlyName: 'Nest Mini Kitchen',
            host: InternetAddress('192.168.1.40'),
          ),
        ],
      ),
      overrides: [
        savedHomeSpeakerProvider.overrideWith((ref) async {
          final tick = ref.watch(speakerTick);
          if (tick == 0) return null;
          return const SavedHomeSpeaker(
            deviceId: 'nest-1',
            friendlyName: 'Nest Mini Kitchen',
          );
        }),
      ],
    );

    expect((await store.read()).step, OnboardingStep.speaker);
    expect((await prefs.read()).defaultDeliveryMode, PrayerDeliveryMode.beep);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingGate)),
    );
    container.read(speakerTick.notifier).state = 1;
    await tester.pump();
    await tester.pump();

    expect((await prefs.read()).defaultDeliveryMode, PrayerDeliveryMode.cast);
    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await store.read()).back, OnboardingStep.speaker);
  });

  testWidgets('empty scan phone button goes to the phone step', (tester) async {
    final store = MemoryOnboardingStore(speakerRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await pumpSpeakerGate(
      tester,
      store: store,
      prefs: prefs,
      overrides: [savedHomeSpeakerProvider.overrideWith((ref) async => null)],
    );

    expect(find.byKey(const ValueKey('household_code_menu')), findsNothing);
    expect(find.byKey(const ValueKey('onboarding_progress')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding_use_phone_audio')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.phone);
    expect((await store.read()).back, OnboardingStep.speaker);
  });

  testWidgets('back returns to the audio step', (tester) async {
    final store = MemoryOnboardingStore(speakerRecord());
    final prefs = MemoryPrayerPrefsStore(PrayerPrefs.defaults);

    await pumpSpeakerGate(
      tester,
      store: store,
      prefs: prefs,
      overrides: [savedHomeSpeakerProvider.overrideWith((ref) async => null)],
    );

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.audio);
    expect((await store.read()).back, isNull);
  });
}
