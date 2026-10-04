import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/indonesia_location.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Resolves location into prayer prefs on this screen, then continues.
class OnboardingPrayerStep extends ConsumerStatefulWidget {
  const OnboardingPrayerStep({
    super.key,
    required this.record,
    this.locationResolver = const LocationResolver(),
  });

  final OnboardingRecord record;
  final LocationResolving locationResolver;

  @override
  ConsumerState<OnboardingPrayerStep> createState() =>
      _OnboardingPrayerStepState();
}

class _OnboardingPrayerStepState extends ConsumerState<OnboardingPrayerStep> {
  var _busy = false;
  String? _status;
  PrayerPrefs? _resolved;

  Future<void> _useLocation() async {
    if (_busy) return;
    final l10n = context.l10n;
    final resolver = widget.locationResolver;

    // Skip the Play-prominent location disclosure here — first-run stays light.
    // Prayer times still shows it when the user picks location after setup.
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      final resolved = await resolver.resolveCurrent();
      if (!mounted) return;
      final store = ref.read(prayerPrefsStoreProvider);
      final current = await store.read();
      final next = current.copyWith(
        city: resolved.city,
        country: resolved.country,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
        administrativeArea: resolved.administrativeArea,
        methodId: methodIdForLocationDetect(
          country: resolved.country,
          currentMethodId: current.methodId,
          previousAladhanMethodId: isKemenagMethod(current.methodId)
              ? defaultAladhanMethodId
              : current.methodId,
        ),
        configured: true,
        defaultsMigrated: true,
      );
      await store.write(next);
      ref.read(adhanNextPrayerProvider).invalidateCache();
      ref.invalidate(prayerPrefsProvider);
      ref.invalidate(nextPrayerSnapshotProvider);
      if (!mounted) return;
      setState(() {
        _resolved = next;
        _busy = false;
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = locationErrorMessage(l10n, e);
        _busy = false;
      });
    }
  }

  Future<void> _continue() {
    return OnboardingController.go(
      ref,
      OnboardingStep.notifications,
      back: OnboardingStep.prayer,
    );
  }

  String _methodLabel(AppLocalizations l10n, int methodId) {
    if (isKemenagMethod(methodId)) return l10n.methodKemenag;
    for (final method in AladhanMethods.common) {
      if (method.id == methodId) return method.label;
    }
    return l10n.voiceStandard;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final back = widget.record.back;
    final resolved = _resolved;
    final text = Theme.of(context).textTheme;

    if (resolved != null) {
      final resultBody = [
        l10n.onboardingPrayerResultCity(resolved.city),
        l10n.onboardingPrayerResultCountry(resolved.country),
        l10n.onboardingPrayerResultMethod(
          _methodLabel(l10n, resolved.methodId),
        ),
      ].join('\n');

      return OnboardingShell(
        stage: OnboardingStage.prayer,
        eyebrow: l10n.onboardingAudioEyebrow,
        title: l10n.onboardingPrayerTitle,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingMarkWell(
              size: 112,
              iconSize: 44,
              child: PremiumIcons.house(size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              resultBody,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(
                color: PrayerCastTokens.glyph(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              key: const ValueKey('onboarding_prayer_retry'),
              onPressed: _busy ? null : () => _useLocation().ignore(),
              style: TextButton.styleFrom(
                foregroundColor: PrayerCastColors.dawn,
                minimumSize: const Size(0, PrayerCastTheme.minTap),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                l10n.onboardingPrayerRetry,
                style: const TextStyle(
                  color: PrayerCastColors.dawn,
                  fontWeight: FontWeight.w700,
                  fontFamily: PrayerCastTheme.bodyFont,
                ),
              ),
            ),
          ],
        ),
        onBack: back == null
            ? null
            : () => OnboardingController.go(ref, back, back: null).ignore(),
        secondaryLabel: l10n.onboardingSwipeNext,
        secondaryKey: const ValueKey('onboarding_swipe_hint'),
        onSecondary: () => _continue().ignore(),
      );
    }

    return OnboardingShell(
      stage: OnboardingStage.prayer,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: l10n.onboardingPrayerTitle,
      body: _status ?? l10n.onboardingPrayerBody,
      mark: PremiumIcons.clock(size: 44),
      markKey: const ValueKey('onboarding_open_prayer'),
      markCaption: l10n.onboardingPrayerAction,
      onMarkTap: () => _useLocation().ignore(),
      busy: _busy,
      onBack: back == null
          ? null
          : () => OnboardingController.go(ref, back, back: null).ignore(),
    );
  }
}
