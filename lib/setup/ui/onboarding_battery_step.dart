import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

/// Last onboarding step. Open or skip both finish setup.
class OnboardingBatteryStep extends ConsumerWidget {
  const OnboardingBatteryStep({super.key, required this.record});

  final OnboardingRecord record;

  Future<void> _finish(WidgetRef ref) {
    return OnboardingController.go(ref, OnboardingStep.completed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final back = record.back;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.onboardingAudioEyebrow,
        title: l10n.onboardingBatteryTitle,
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
                key: const ValueKey('onboarding_battery_open'),
                onPressed: () {
                  ref
                      .read(oemBatterySettingsProvider)
                      .open()
                      .then((_) => _finish(ref))
                      .ignore();
                },
                child: Text(l10n.onboardingBatteryOpen),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: TextButton(
                key: const ValueKey('onboarding_battery_skip'),
                onPressed: () => _finish(ref).ignore(),
                child: Text(l10n.onboardingBatterySkip),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
