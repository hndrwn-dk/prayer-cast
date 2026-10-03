import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/speaker_setup_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_audio_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_phone_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_prayer_step.dart';

/// Resolves onboarding once, then shows home or the current onboarding step.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.home});

  final Widget home;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  late final Future<OnboardingRecord> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = OnboardingController.resolve(ref);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnboardingRecord>(
      future: _resolved,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) {
          return Scaffold(backgroundColor: PrayerCastTokens.surface(context));
        }
        return _OnboardingResolved(resolved: resolved, home: widget.home);
      },
    );
  }
}

/// After [OnboardingController.resolve], follow [onboardingStepProvider] when
/// its record has a step. A null step keeps the resolved record so a fresh
/// install still opens on the written audio step.
class _OnboardingResolved extends ConsumerWidget {
  const _OnboardingResolved({required this.resolved, required this.home});

  final OnboardingRecord resolved;
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(onboardingStepProvider).valueOrNull;
    final record = live != null && live.step != null ? live : resolved;
    if (record.step == OnboardingStep.speaker) {
      ref.listen(savedHomeSpeakerProvider, (previous, next) {
        final nextSpeaker = next.asData?.value;
        if (nextSpeaker == null) return;
        final previousWasEmpty =
            previous != null && previous.hasValue && previous.value == null;
        if (!previousWasEmpty) return;
        OnboardingController.setDelivery(ref, PrayerDeliveryMode.cast).then((
          _,
        ) {
          return OnboardingController.go(
            ref,
            OnboardingStep.prayer,
            back: OnboardingStep.speaker,
          );
        }).ignore();
      });
    }
    final back = record.back;
    return switch (record.step) {
      OnboardingStep.completed => home,
      OnboardingStep.phone => OnboardingPhoneStep(record: record),
      OnboardingStep.prayer => OnboardingPrayerStep(record: record),
      OnboardingStep.speaker => SpeakerSetupPage(
        onboarding: true,
        onUsePhoneAudio: () {
          OnboardingController.go(
            ref,
            OnboardingStep.phone,
            back: OnboardingStep.speaker,
          ).ignore();
        },
        onBack: back == null
            ? null
            : () => OnboardingController.go(ref, back, back: null).ignore(),
      ),
      OnboardingStep.audio || _ => const OnboardingAudioStep(),
    };
  }
}
