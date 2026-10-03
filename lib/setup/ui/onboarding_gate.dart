import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_audio_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_phone_step.dart';

/// Resolves onboarding once, then shows home, the phone step, or the audio
/// step.
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
    final live = ref.watch(onboardingStepProvider).asData?.value;
    final record = live != null && live.step != null ? live : resolved;
    return switch (record.step) {
      OnboardingStep.completed => home,
      OnboardingStep.phone => OnboardingPhoneStep(record: record),
      // speaker stays here until Task 5.
      OnboardingStep.audio ||
      OnboardingStep.speaker => const OnboardingAudioStep(),
      _ => const OnboardingAudioStep(),
    };
  }
}
