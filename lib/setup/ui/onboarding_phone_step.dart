import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Phone delivery choice: adhan or a short beep — two center mark CTAs.
class OnboardingPhoneStep extends ConsumerWidget {
  const OnboardingPhoneStep({super.key, required this.record});

  final OnboardingRecord record;

  Future<void> _pick(WidgetRef ref, PrayerDeliveryMode mode) {
    return OnboardingController.setDelivery(ref, mode).then((_) {
      return OnboardingController.go(
        ref,
        OnboardingStep.prayer,
        back: OnboardingStep.phone,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final back = record.back;
    return OnboardingShell(
      stage: OnboardingStage.delivery,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: l10n.onboardingPhoneTitle,
      center: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OnboardingMarkChoice(
            key: const ValueKey('onboarding_phone_adhan'),
            icon: PremiumIcons.moon(size: 40),
            label: l10n.onboardingPhoneAdhan,
            onTap: () => _pick(ref, PrayerDeliveryMode.adhanPhone).ignore(),
          ),
          const SizedBox(width: 28),
          OnboardingMarkChoice(
            key: const ValueKey('onboarding_phone_beep'),
            icon: PremiumIcons.phone(size: 40),
            label: l10n.onboardingPhoneBeep,
            onTap: () => _pick(ref, PrayerDeliveryMode.beep).ignore(),
          ),
        ],
      ),
      onBack: back == null
          ? null
          : () => OnboardingController.go(ref, back, back: null).ignore(),
    );
  }
}
