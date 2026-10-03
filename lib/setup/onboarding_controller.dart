import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

abstract final class OnboardingController {
  static Future<OnboardingRecord> resolve(WidgetRef ref) async {
    final store = ref.read(onboardingStoreProvider);
    final current = await store.read();
    if (current.step != null) return current;
    final prefs = await ref.read(prayerPrefsProvider.future);
    final next = OnboardingRecord(
      step: prefs.configured ? OnboardingStep.completed : OnboardingStep.audio,
    );
    await store.write(next);
    return next;
  }

  static Future<void> go(
    WidgetRef ref,
    OnboardingStep step, {
    OnboardingStep? back,
  }) async {
    await ref
        .read(onboardingStoreProvider)
        .write(OnboardingRecord(step: step, back: back));
    ref.invalidate(onboardingStepProvider);
  }
}

final onboardingStepProvider = FutureProvider<OnboardingRecord>((ref) async {
  return ref.watch(onboardingStoreProvider).read();
});
