import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_audio_step.dart';

/// Resolves onboarding once, then shows home or the audio step.
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
        final record = snapshot.data;
        if (record == null) {
          return Scaffold(backgroundColor: PrayerCastTokens.surface(context));
        }
        return switch (record.step) {
          OnboardingStep.completed => widget.home,
          // speaker and phone stay here until Tasks 4 and 5.
          OnboardingStep.audio ||
          OnboardingStep.speaker ||
          OnboardingStep.phone => const OnboardingAudioStep(),
          _ => const OnboardingAudioStep(),
        };
      },
    );
  }
}
