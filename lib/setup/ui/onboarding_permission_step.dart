import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

/// Permission prompt — center mark is the primary action (same as battery).
class OnboardingPermissionStep extends StatefulWidget {
  const OnboardingPermissionStep({
    super.key,
    required this.stage,
    required this.title,
    required this.body,
    required this.action,
    required this.actionKey,
    required this.onRequest,
    required this.onFinished,
    required this.mark,
    this.awaitRequest = true,
    this.onBack,
  });

  final OnboardingStage stage;
  final String title;
  final String body;
  final String action;
  final Key actionKey;
  final Future<void> Function() onRequest;
  final VoidCallback onFinished;
  final Widget mark;

  /// When false (exact-alarm Settings), open Settings then advance.
  final bool awaitRequest;
  final VoidCallback? onBack;

  @override
  State<OnboardingPermissionStep> createState() =>
      _OnboardingPermissionStepState();
}

class _OnboardingPermissionStepState extends State<OnboardingPermissionStep> {
  var _busy = false;

  Future<void> _runAction() async {
    if (_busy) return;
    final finish = widget.onFinished;
    final request = widget.onRequest;

    if (!widget.awaitRequest) {
      try {
        await request();
      } catch (_) {}
      finish();
      return;
    }

    setState(() => _busy = true);
    try {
      await request();
    } catch (_) {
      // Still advance — denying notifications must not trap the step.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    finish();
  }

  void _skip() {
    if (_busy) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnboardingShell(
      stage: widget.stage,
      eyebrow: l10n.onboardingAudioEyebrow,
      title: widget.title,
      body: widget.body,
      mark: widget.mark,
      markKey: widget.actionKey,
      markCaption: widget.action,
      onMarkTap: _busy ? null : () => _runAction().ignore(),
      busy: widget.awaitRequest && _busy,
      onBack: _busy ? null : widget.onBack,
      secondaryLabel: l10n.onboardingSwipeNext,
      secondaryKey: const ValueKey('onboarding_swipe_hint'),
      onSecondary: _busy ? null : _skip,
    );
  }
}
