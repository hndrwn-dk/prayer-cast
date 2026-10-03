import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// One permission prompt. Always continues after the request returns.
class OnboardingPermissionStep extends StatelessWidget {
  const OnboardingPermissionStep({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    required this.actionKey,
    required this.onRequest,
    required this.onFinished,
    this.onBack,
  });

  final String title;
  final String body;
  final String action;
  final Key actionKey;
  final Future<void> Function() onRequest;
  final VoidCallback onFinished;
  final VoidCallback? onBack;

  Future<void> _continue() async {
    try {
      await onRequest();
    } catch (_) {}
    onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.onboardingAudioEyebrow,
        title: title,
        backButtonKey: const ValueKey('onboarding_back'),
        onBack: onBack,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              body,
              style: text.bodyLarge?.copyWith(
                color: PrayerCastTokens.glyph(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                key: actionKey,
                onPressed: () => _continue().ignore(),
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
