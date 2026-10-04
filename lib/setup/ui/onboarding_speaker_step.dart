import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_device_kind.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/cast_scan_spinner.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Simple first-run speaker pick: scan, tap to save, or use this phone.
///
/// No household code, multi-select, or battery banner — those stay on
/// [SpeakerSetupPage] after onboarding.
class OnboardingSpeakerStep extends ConsumerStatefulWidget {
  const OnboardingSpeakerStep({super.key, required this.record});

  final OnboardingRecord record;

  @override
  ConsumerState<OnboardingSpeakerStep> createState() =>
      _OnboardingSpeakerStepState();
}

class _OnboardingSpeakerStepState extends ConsumerState<OnboardingSpeakerStep> {
  String? _savingDeviceId;

  void _rescan() {
    if (_savingDeviceId != null) return;
    ref.read(hiddenSpeakerIdsProvider.notifier).state = const {};
    ref.read(speakerScanEpochProvider.notifier).state++;
  }

  Future<void> _select(CastReceiver receiver) async {
    if (_savingDeviceId != null) return;
    setState(() => _savingDeviceId = receiver.deviceId);
    try {
      await ref.read(homeOnboardingProvider).saveHomeSpeaker(receiver);
      ref.invalidate(savedHomeSpeakerProvider);
      // Gate listens for the saved speaker and advances to prayer.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.speakerSaveFailed('$e'))),
      );
      setState(() => _savingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final back = widget.record.back;
    final discovery = ref.watch(speakerDiscoveryProvider);
    final hiddenIds = ref.watch(hiddenSpeakerIdsProvider);
    final isInitialLoading = discovery.isLoading && !discovery.hasValue;
    final isRefreshing = discovery.isLoading && discovery.hasValue;
    final speakers = discovery.hasValue
        ? filterSpeakerCastTargets(
            discovery.requireValue.devices,
            (d) => d.friendlyName,
          ).where((d) => !hiddenIds.contains(d.deviceId)).toList()
        : const <CastReceiver>[];
    final busy = _savingDeviceId != null;

    return OnboardingShell(
      stage: OnboardingStage.delivery,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: l10n.speakerSetupTitle,
      onBack: busy || back == null
          ? null
          : () => OnboardingController.go(ref, back, back: null).ignore(),
      busy: busy,
      bodySlot: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.speakerSetupIntro,
              style: text.bodyLarge?.copyWith(
                color: PrayerCastTokens.glyph(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isInitialLoading || isRefreshing
                        ? l10n.scanning
                        : l10n.speakersFound(speakers.length),
                    style: text.titleSmall?.copyWith(
                      color: PrayerCastColors.dawn,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('onboarding_speaker_rescan'),
                  tooltip: l10n.scanAgain,
                  onPressed: isInitialLoading || isRefreshing || busy
                      ? null
                      : _rescan,
                  icon: isRefreshing
                      ? CastScanSpinner(
                          size: 18,
                          strokeWidth: 2.2,
                          color: PrayerCastColors.dawn,
                          trackColor: PrayerCastTokens.track(context),
                          pulse: false,
                        )
                      : PremiumIcons.refresh(
                          size: 22,
                          color: PrayerCastColors.dawn,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: discovery.when(
                skipLoadingOnReload: true,
                skipError: true,
                loading: () => const Center(child: CastScanSpinner(size: 36)),
                error: (error, _) => Center(
                  child: Text(
                    l10n.speakerScanFailed('$error'),
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                ),
                data: (result) {
                  if (speakers.isEmpty) {
                    if (isRefreshing) {
                      return const Center(child: CastScanSpinner(size: 36));
                    }
                    return Center(
                      child: Text(
                        l10n.noSpeakersFoundGuidance,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(
                          color: PrayerCastTokens.glyph(context),
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: speakers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final speaker = speakers[index];
                      final saving = _savingDeviceId == speaker.deviceId;
                      return _SpeakerPickTile(
                        key: ValueKey(
                          'onboarding_speaker_${speaker.deviceId}',
                        ),
                        name: speaker.friendlyName,
                        saving: saving,
                        enabled: !busy,
                        onTap: () => _select(speaker).ignore(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      secondaryLabel: l10n.onboardingUsePhoneAudio,
      secondaryKey: const ValueKey('onboarding_use_phone_audio'),
      onSecondary: () => OnboardingController.go(
        ref,
        OnboardingStep.phone,
        back: OnboardingStep.speaker,
      ).ignore(),
    );
  }
}

/// Raised pick row — dawn ring icon + hairline edge (not a flat slab).
class _SpeakerPickTile extends StatelessWidget {
  const _SpeakerPickTile({
    super.key,
    required this.name,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: PrayerCastTokens.slab(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: PrayerCastColors.dawn.withValues(
            alpha: PrayerCastTokens.isForest(context) ? 0.55 : 0.42,
          ),
          width: 1.1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PrayerCastTokens.dawnWash(context),
                  border: Border.all(
                    color: PrayerCastColors.dawn.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: PremiumIcons.speaker(
                  size: 24,
                  color: PrayerCastColors.dawn,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: text.titleMedium?.copyWith(
                    color: PrayerCastTokens.onSurface(context),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (saving)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: PrayerCastColors.dawn,
                  ),
                )
              else
                PremiumIcons.caretRight(
                  size: 22,
                  color: PrayerCastColors.dawn,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
