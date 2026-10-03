import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/setup/ui/onboarding_gate.dart';

void main() {
  Future<void> pumpGate(
    WidgetTester tester, {
    required MemoryOnboardingStore store,
    Future<void> Function()? requestNotifications,
    Future<void> Function()? requestExactAlarm,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingGate(
            home: const Scaffold(body: Text('HOME')),
            requestNotifications: requestNotifications,
            requestExactAlarm: requestExactAlarm,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('notifications denied still advances to alarm', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.notifications,
        back: OnboardingStep.prayer,
      ),
    );
    var requests = 0;
    await pumpGate(
      tester,
      store: store,
      requestNotifications: () async {
        requests++;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('onboarding_notifications_continue')),
    );
    await tester.pump();

    expect(requests, 1);
    expect((await store.read()).step, OnboardingStep.alarm);
    expect((await store.read()).back, OnboardingStep.notifications);
  });

  testWidgets('alarm denied still advances to battery', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.alarm,
        back: OnboardingStep.notifications,
      ),
    );
    var requests = 0;
    await pumpGate(
      tester,
      store: store,
      requestExactAlarm: () async {
        requests++;
      },
    );

    await tester.tap(find.byKey(const ValueKey('onboarding_alarm_continue')));
    await tester.pump();

    expect(requests, 1);
    expect((await store.read()).step, OnboardingStep.battery);
    expect((await store.read()).back, OnboardingStep.alarm);
  });

  testWidgets('back from notifications returns to prayer', (tester) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.notifications,
        back: OnboardingStep.prayer,
      ),
    );
    await pumpGate(tester, store: store, requestNotifications: () async {});

    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.prayer);
    expect((await store.read()).back, isNull);
  });
}
