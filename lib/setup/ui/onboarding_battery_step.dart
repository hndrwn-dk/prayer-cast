import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Last onboarding step. Mark opens battery settings; Continue finishes.
class OnboardingBatteryStep extends ConsumerStatefulWidget {
  const OnboardingBatteryStep({super.key, required this.record});

  final OnboardingRecord record;

  @override
  ConsumerState<OnboardingBatteryStep> createState() =>
      _OnboardingBatteryStepState();
}

class _OnboardingBatteryStepState extends ConsumerState<OnboardingBatteryStep> {
  var _busy = false;

  Future<void> _finish() {
    return OnboardingController.go(ref, OnboardingStep.completed);
  }

  Future<void> _openSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Stay on this step so Settings / Allow dialog stay in front.
      // Finishing immediately used to yank the user back to app home.
      await ref.read(oemBatterySettingsProvider).open();
    } catch (_) {
      // Still leave the step interactive.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final back = widget.record.back;
    return OnboardingShell(
      stage: OnboardingStage.battery,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: l10n.onboardingBatteryTitle,
      mark: PremiumIcons.batteryWarning(size: 40),
      markKey: const ValueKey('onboarding_battery_open'),
      markCaption: l10n.onboardingBatteryOpen,
      onMarkTap: _busy ? null : () => _openSettings().ignore(),
      busy: _busy,
      onBack: _busy || back == null
          ? null
          : () => OnboardingController.go(ref, back, back: null).ignore(),
      secondaryLabel: l10n.onboardingSwipeNext,
      secondaryKey: const ValueKey('onboarding_swipe_hint'),
      onSecondary: _busy ? null : () => _finish().ignore(),
    );
  }
}
