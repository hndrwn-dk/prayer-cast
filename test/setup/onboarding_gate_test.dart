import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

void main() {
  testWidgets('fresh install opens the audio step, not home', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(database: db, onboarding: store),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsOneWidget,
    );
    expect(find.text('ADZAN BERIKUTNYA'), findsNothing);
    expect(await store.read(), isNot(OnboardingRecord.notStarted));
    expect((await store.read()).step, OnboardingStep.audio);
  });

  testWidgets('configured install opens home and marks onboarding completed', (
    tester,
  ) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        onboarding: store,
        prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsNothing,
    );
    expect((await store.read()).step, OnboardingStep.completed);
    // Home fade-ins schedule short timers. Advance past them so the
    // test binding does not fail on a pending timer at dispose.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
