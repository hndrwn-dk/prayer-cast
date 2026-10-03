import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/platform/post_notifications_permission.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/speaker_setup_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_controller.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_audio_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_battery_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_phone_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_permission_step.dart';
import 'package:prayer_cast/setup/ui/onboarding_prayer_step.dart';

/// Resolves onboarding once, then shows home or the current onboarding step.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({
    super.key,
    required this.home,
    this.exactAlarm,
    this.requestNotifications,
    this.requestExactAlarm,
  });

  final Widget home;
  final ExactAlarmPlatform? exactAlarm;

  /// Test / injection hook. Production uses [PostNotificationsPermission].
  final Future<void> Function()? requestNotifications;

  /// Test / injection hook. Production uses [exactAlarm].
  final Future<void> Function()? requestExactAlarm;

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
        return _OnboardingResolved(
          resolved: resolved,
          home: widget.home,
          exactAlarm: widget.exactAlarm,
          requestNotifications: widget.requestNotifications,
          requestExactAlarm: widget.requestExactAlarm,
        );
      },
    );
  }
}

/// After [OnboardingController.resolve], follow [onboardingStepProvider] when
/// its record has a step. A null step keeps the resolved record so a fresh
/// install still opens on the written audio step.
class _OnboardingResolved extends ConsumerWidget {
  const _OnboardingResolved({
    required this.resolved,
    required this.home,
    this.exactAlarm,
    this.requestNotifications,
    this.requestExactAlarm,
  });

  final OnboardingRecord resolved;
  final Widget home;
  final ExactAlarmPlatform? exactAlarm;
  final Future<void> Function()? requestNotifications;
  final Future<void> Function()? requestExactAlarm;

  VoidCallback? _back(WidgetRef ref, OnboardingRecord record) {
    final back = record.back;
    if (back == null) return null;
    return () => OnboardingController.go(ref, back, back: null).ignore();
  }

  Future<void> _askNotifications() async {
    final ask = requestNotifications;
    if (ask != null) {
      await ask();
      return;
    }
    await const PostNotificationsPermission().request();
  }

  Future<void> _askExactAlarm() async {
    final ask = requestExactAlarm;
    if (ask != null) {
      await ask();
      return;
    }
    await exactAlarm?.requestExactAlarmPermission();
  }

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
    final l10n = context.l10n;
    final back = record.back;
    return switch (record.step) {
      OnboardingStep.completed => home,
      OnboardingStep.phone => OnboardingPhoneStep(record: record),
      OnboardingStep.prayer => OnboardingPrayerStep(record: record),
      OnboardingStep.battery => OnboardingBatteryStep(record: record),
      OnboardingStep.notifications => OnboardingPermissionStep(
        title: l10n.notificationsBlockedTitle,
        body: l10n.notificationsBlockedBody,
        action: l10n.notificationsBlockedAllow,
        actionKey: const ValueKey('onboarding_notifications_continue'),
        onRequest: _askNotifications,
        onBack: _back(ref, record),
        onFinished: () {
          OnboardingController.go(
            ref,
            OnboardingStep.alarm,
            back: OnboardingStep.notifications,
          ).ignore();
        },
      ),
      OnboardingStep.alarm => OnboardingPermissionStep(
        title: l10n.exactAlarmTitle,
        body: l10n.exactAlarmBody,
        action: l10n.exactAlarmOpenSettings,
        actionKey: const ValueKey('onboarding_alarm_continue'),
        onRequest: _askExactAlarm,
        onBack: _back(ref, record),
        onFinished: () {
          OnboardingController.go(
            ref,
            OnboardingStep.battery,
            back: OnboardingStep.alarm,
          ).ignore();
        },
      ),
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
