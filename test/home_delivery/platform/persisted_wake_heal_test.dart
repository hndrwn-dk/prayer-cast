import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/persisted_wake_heal.dart';

void main() {
  group('persistedWakeHealAction', () {
    test('unacked real pending fire replays before rearm or retry', () {
      expect(
        persistedWakeHealAction(
          storedEpochMs: 2_000,
          nowMs: 1_000,
          pendingPrayer: 'maghrib',
        ),
        PersistedWakeHealAction.replayPendingFire,
      );
      expect(
        persistedWakeHealAction(
          storedEpochMs: 500,
          nowMs: 1_000,
          pendingPrayer: 'dhuhr',
        ),
        PersistedWakeHealAction.replayPendingFire,
      );
    });

    test('reschedule-retry pending does not force replay', () {
      expect(
        persistedWakeHealAction(
          storedEpochMs: 500,
          nowMs: 1_000,
          pendingPrayer: kRescheduleRetryPrayer,
          storedPrayer: 'maghrib',
        ),
        // Past maghrib wake still within grace → fire overdue, not retry.
        PersistedWakeHealAction.fireOverduePrefs,
      );
    });

    test('future epoch rearms the same prefs wake', () {
      expect(
        persistedWakeHealAction(storedEpochMs: 2_000, nowMs: 1_000),
        PersistedWakeHealAction.rearmFromPrefs,
      );
    });

    test('past wake within azan grace fires overdue prefs', () {
      // Wake at 0; azan at 120_000; now at wake+90s (azan still 30s away).
      expect(
        persistedWakeHealAction(
          storedEpochMs: 0,
          nowMs: 90_000,
          storedPrayer: 'maghrib',
        ),
        PersistedWakeHealAction.fireOverduePrefs,
      );
    });

    test('past epoch beyond azan grace uses armRescheduleRetry', () {
      // Wake at 0; azan at 120_000; grace ends at 120_000+5min.
      final pastGrace = 120_000 + kOverdueDeliveryGrace.inMilliseconds + 1;
      expect(
        persistedWakeHealAction(
          storedEpochMs: 0,
          nowMs: pastGrace,
          storedPrayer: 'maghrib',
        ),
        PersistedWakeHealAction.armRescheduleRetry,
      );
    });

    test('missing epoch uses armRescheduleRetry', () {
      expect(
        persistedWakeHealAction(storedEpochMs: null, nowMs: 1_000),
        PersistedWakeHealAction.armRescheduleRetry,
      );
    });
  });

  test('isRealPendingPrayer rejects empty and reschedule-retry', () {
    expect(isRealPendingPrayer(null), isFalse);
    expect(isRealPendingPrayer(''), isFalse);
    expect(isRealPendingPrayer(kRescheduleRetryPrayer), isFalse);
    expect(isRealPendingPrayer('fajr'), isTrue);
  });

  test('heal prefers replay, then rearm, then overdue, then retry', () {
    var replay = 0;
    var rearm = 0;
    var overdue = 0;
    var retry = 0;
    void replayPendingFire() => replay++;
    void rearmFromPrefs() => rearm++;
    void fireOverduePrefs() => overdue++;
    void armRescheduleRetry() => retry++;

    runPersistedWakeHeal(
      storedEpochMs: 100,
      nowMs: 200,
      pendingPrayer: 'asr',
      storedPrayer: 'asr',
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      fireOverduePrefs: fireOverduePrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: 100,
      nowMs: 200,
      pendingPrayer: null,
      storedPrayer: 'maghrib',
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      fireOverduePrefs: fireOverduePrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: null,
      nowMs: 200,
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      fireOverduePrefs: fireOverduePrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: 400,
      nowMs: 200,
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      fireOverduePrefs: fireOverduePrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    final pastGrace = 120_000 + kOverdueDeliveryGrace.inMilliseconds + 1;
    runPersistedWakeHeal(
      storedEpochMs: 0,
      nowMs: pastGrace,
      storedPrayer: 'maghrib',
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      fireOverduePrefs: fireOverduePrefs,
      armRescheduleRetry: armRescheduleRetry,
    );

    expect(replay, 1);
    expect(overdue, 1);
    expect(retry, 2);
    expect(rearm, 1);
  });
}
