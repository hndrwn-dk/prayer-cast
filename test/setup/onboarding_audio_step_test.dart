import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_audio_step.dart';

void main() {
  Future<void> pumpAudioStep(
    WidgetTester tester,
    MemoryOnboardingStore store,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          locale: Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingAudioStep(),
        ),
      ),
    );
  }

  testWidgets('speaker choice writes speaker with back audio', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(step: OnboardingStep.audio),
    );
    await pumpAudioStep(tester, store);

    await tester.tap(find.byKey(const ValueKey('onboarding_audio_speaker')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.speaker);
    expect((await store.read()).back, OnboardingStep.audio);
  });

  testWidgets('phone choice writes phone with back audio', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(step: OnboardingStep.audio),
    );
    await pumpAudioStep(tester, store);

    await tester.tap(find.byKey(const ValueKey('onboarding_audio_phone')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.phone);
    expect((await store.read()).back, OnboardingStep.audio);
  });
}
