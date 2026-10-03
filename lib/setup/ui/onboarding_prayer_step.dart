import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/prayer_times/ui/prayer_settings_page.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

/// Prayer times must be saved before onboarding can continue.
class OnboardingPrayerStep extends ConsumerWidget {
  const OnboardingPrayerStep({super.key, required this.record});

  final OnboardingRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final back = record.back;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.onboardingAudioEyebrow,
        title: l10n.onboardingPrayerTitle,
        backButtonKey: const ValueKey('onboarding_back'),
        onBack: back == null
            ? null
            : () => OnboardingController.go(ref, back, back: null).ignore(),
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
                key: const ValueKey('onboarding_open_prayer'),
                onPressed: () {
                  Navigator.of(context)
                      .push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => const PrayerSettingsPage(),
                        ),
                      )
                      .then((_) {
                        return ref.read(prayerPrefsStoreProvider).read().then((
                          prefs,
                        ) {
                          if (!prefs.configured) return null;
                          return OnboardingController.go(
                            ref,
                            OnboardingStep.notifications,
                            back: OnboardingStep.prayer,
                          );
                        });
                      })
                      .ignore();
                },
                child: Text(l10n.onboardingPrayerAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
