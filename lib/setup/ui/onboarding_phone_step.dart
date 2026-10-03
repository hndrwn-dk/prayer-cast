import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

/// Phone delivery choice: adhan or a short beep.
class OnboardingPhoneStep extends ConsumerWidget {
  const OnboardingPhoneStep({super.key, required this.record});

  final OnboardingRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final back = record.back;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.onboardingAudioEyebrow,
        title: l10n.onboardingPhoneTitle,
        backButtonKey: const ValueKey('onboarding_back'),
        onBack: back == null
            ? null
            : () {
                OnboardingController.go(ref, back, back: null);
              },
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
                key: const ValueKey('onboarding_phone_adhan'),
                onPressed: () async {
                  await OnboardingController.setDelivery(
                    ref,
                    PrayerDeliveryMode.adhanPhone,
                  );
                  await OnboardingController.go(
                    ref,
                    OnboardingStep.prayer,
                    back: OnboardingStep.phone,
                  );
                },
                child: Text(l10n.onboardingPhoneAdhan),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: TextButton(
                key: const ValueKey('onboarding_phone_beep'),
                onPressed: () async {
                  await OnboardingController.setDelivery(
                    ref,
                    PrayerDeliveryMode.beep,
                  );
                  await OnboardingController.go(
                    ref,
                    OnboardingStep.prayer,
                    back: OnboardingStep.phone,
                  );
                },
                child: Text(l10n.onboardingPhoneBeep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
