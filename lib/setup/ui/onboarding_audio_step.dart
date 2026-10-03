import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

/// Audio choice: home speaker or this phone.
class OnboardingAudioStep extends ConsumerWidget {
  const OnboardingAudioStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.onboardingAudioEyebrow,
        title: l10n.onboardingAudioTitle,
        onBack: null,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                key: const ValueKey('onboarding_audio_speaker'),
                onPressed: () => OnboardingController.go(
                  ref,
                  OnboardingStep.speaker,
                  back: OnboardingStep.audio,
                ),
                child: Text(l10n.onboardingAudioSpeaker),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: TextButton(
                key: const ValueKey('onboarding_audio_phone'),
                onPressed: () => OnboardingController.go(
                  ref,
                  OnboardingStep.phone,
                  back: OnboardingStep.audio,
                ),
                child: Text(l10n.onboardingAudioPhone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
