import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Audio choice: home speaker or this phone — two center mark CTAs.
class OnboardingAudioStep extends ConsumerWidget {
  const OnboardingAudioStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return OnboardingShell(
      stage: OnboardingStage.audio,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: l10n.onboardingAudioTitle,
      center: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OnboardingMarkChoice(
            key: const ValueKey('onboarding_audio_speaker'),
            icon: PremiumIcons.speaker(size: 40),
            label: l10n.onboardingAudioSpeaker,
            onTap: () => OnboardingController.go(
              ref,
              OnboardingStep.speaker,
              back: OnboardingStep.audio,
            ),
          ),
          const SizedBox(width: 28),
          OnboardingMarkChoice(
            key: const ValueKey('onboarding_audio_phone'),
            icon: PremiumIcons.phone(size: 40),
            label: l10n.onboardingAudioPhone,
            onTap: () => OnboardingController.go(
              ref,
              OnboardingStep.phone,
              back: OnboardingStep.audio,
            ),
          ),
        ],
      ),
    );
  }
}
