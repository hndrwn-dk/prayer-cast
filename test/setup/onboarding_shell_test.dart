import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/setup/ui/onboarding_shell.dart';

void main() {
  testWidgets('shell shows progress and centers the mark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OnboardingShell(
          stage: OnboardingStage.prayer,
          eyebrow: 'Setup',
          title: 'Set prayer times',
          mark: PremiumIcons.clock(size: 40),
          markCaption: 'Use current location',
          onMarkTap: () {},
          onBack: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('onboarding_progress')), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
    expect(find.text('Set prayer times'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.byType(OnboardingMarkWell), findsOneWidget);

    final progressY = tester
        .getCenter(find.byKey(const ValueKey('onboarding_progress')))
        .dy;
    final markY = tester.getCenter(find.byType(OnboardingMarkWell)).dy;
    expect(progressY, lessThan(markY));
  });
}
