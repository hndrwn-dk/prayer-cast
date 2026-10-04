import 'dart:async';

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
    await tester.pump();

    expect(requests, 1);
    expect((await store.read()).step, OnboardingStep.alarm);
    expect((await store.read()).back, OnboardingStep.notifications);
  });

  testWidgets('notifications advance even if request outlives the step', (
    tester,
  ) async {
    final store = MemoryOnboardingStore(
      const OnboardingRecord(
        step: OnboardingStep.notifications,
        back: OnboardingStep.prayer,
      ),
    );
    final released = Completer<void>();
    await pumpGate(
      tester,
      store: store,
      requestNotifications: () => released.future,
    );

    await tester.tap(
      find.byKey(const ValueKey('onboarding_notifications_continue')),
    );
    await tester.pump();

    // Still waiting on the system dialog — step has not advanced yet.
    expect((await store.read()).step, OnboardingStep.notifications);

    released.complete();
    await tester.pump();
    await tester.pump();

    expect((await store.read()).step, OnboardingStep.alarm);
  });

  testWidgets('alarm mark opens settings path and finishes onboarding', (
    tester,
  ) async {
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
    await tester.pump();

    expect(requests, 1);
    expect((await store.read()).step, OnboardingStep.battery);
    expect((await store.read()).back, OnboardingStep.alarm);
  });

  testWidgets('alarm skip advances to battery without opening settings', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('onboarding_swipe_hint')));
    await tester.pump();
    await tester.pump();

    expect(requests, 0);
    expect((await store.read()).step, OnboardingStep.battery);
    expect((await store.read()).back, OnboardingStep.alarm);
  });

  testWidgets(
    'notifications busy state does not disable alarm step CTAs',
    (tester) async {
      final store = MemoryOnboardingStore(
        const OnboardingRecord(
          step: OnboardingStep.notifications,
          back: OnboardingStep.prayer,
        ),
      );
      final released = Completer<void>();
      var alarmRequests = 0;
      await pumpGate(
        tester,
        store: store,
        requestNotifications: () => released.future,
        requestExactAlarm: () async {
          alarmRequests++;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding_notifications_continue')),
      );
      await tester.pump();

      released.complete();
      await tester.pump();
      await tester.pump();

      expect((await store.read()).step, OnboardingStep.alarm);

      // Fresh State for alarm — Continue must still be tappable.
      await tester.tap(find.byKey(const ValueKey('onboarding_swipe_hint')));
      await tester.pump();
      await tester.pump();

      expect(alarmRequests, 0);
      expect((await store.read()).step, OnboardingStep.battery);
    },
  );
}
