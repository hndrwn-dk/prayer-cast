import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/oem_battery_settings.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';

final class _RecordingOem implements OemBatterySettingsPlatform {
  int openCalls = 0;

  @override
  Future<bool> canOpen() async => true;

  @override
  Future<bool> open() async {
    openCalls++;
    return true;
  }

  @override
  Future<bool> openAutostartSettings() async => false;

  @override
  Future<bool> isRestrictiveOem() async => false;

  @override
  Future<bool> isBatteryUnrestricted() async => false;
}

void main() {
  Future<void> pumpGate(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    OemBatterySettingsPlatform? oem,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          if (oem != null) oemBatterySettingsProvider.overrideWithValue(oem),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingGate(
            home: const Scaffold(body: Text('ADZAN BERIKUTNYA')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('skip finishes onboarding and shows home', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.battery,
        back: OnboardingStep.alarm,
      ),
    );
    await pumpGate(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('onboarding_battery_skip')));
    await tester.pump();
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.completed);
    expect((await store.read()).back, isNull);
    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
  });

  testWidgets('open battery settings then finishes onboarding', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.battery,
        back: OnboardingStep.alarm,
      ),
    );
    final oem = _RecordingOem();
    await pumpGate(tester, store: store, oem: oem);

    await tester.tap(find.byKey(const ValueKey('onboarding_battery_open')));
    await tester.pump();
    await tester.pump();

    expect(oem.openCalls, 1);
    expect((await store.read()).step, OnboardingStep.completed);
    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
  });
}
