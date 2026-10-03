import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

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
        if (record.step == OnboardingStep.completed) return widget.home;
        return const OnboardingAudioStep();
      },
    );
  }
}

/// Placeholder audio choice. Later tasks replace this body.
class OnboardingAudioStep extends StatelessWidget {
  const OnboardingAudioStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final forest = PrayerCastTokens.isForest(context);
    final titleStyle = TextStyle(
      fontFamily: PrayerCastTheme.displayFont,
      fontSize: forest ? 28 : 30,
      fontWeight: forest ? FontWeight.w500 : FontWeight.w600,
      height: 1.2,
      color: forest
          ? PrayerCastColors.surfaceRaised
          : PrayerCastTokens.onSurface(context),
    );
    return Scaffold(
      backgroundColor: PrayerCastTokens.surface(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialEyebrow(
                l10n.onboardingAudioEyebrow,
                color: PrayerCastColors.dawn,
              ),
              const SizedBox(height: 8),
              Text(l10n.onboardingAudioTitle, style: titleStyle),
              const SizedBox(height: 28),
              TextButton(
                key: const ValueKey('onboarding_audio_speaker'),
                onPressed: () {},
                child: Text(l10n.onboardingAudioSpeaker),
              ),
              TextButton(
                key: const ValueKey('onboarding_audio_phone'),
                onPressed: () {},
                child: Text(l10n.onboardingAudioPhone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
