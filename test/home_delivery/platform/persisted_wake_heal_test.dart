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
        ),
        PersistedWakeHealAction.armRescheduleRetry,
      );
    });

    test('future epoch rearms the same prefs wake', () {
      expect(
        persistedWakeHealAction(storedEpochMs: 2_000, nowMs: 1_000),
        PersistedWakeHealAction.rearmFromPrefs,
      );
    });

    test('past epoch uses armRescheduleRetry, not a second path', () {
      expect(
        persistedWakeHealAction(storedEpochMs: 500, nowMs: 1_000),
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

  test('heal prefers replay, then rearm, then retry', () {
    var replay = 0;
    var rearm = 0;
    var retry = 0;
    void replayPendingFire() => replay++;
    void rearmFromPrefs() => rearm++;
    void armRescheduleRetry() => retry++;

    runPersistedWakeHeal(
      storedEpochMs: 100,
      nowMs: 200,
      pendingPrayer: 'asr',
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: 100,
      nowMs: 200,
      pendingPrayer: null,
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: null,
      nowMs: 200,
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: 400,
      nowMs: 200,
      replayPendingFire: replayPendingFire,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );

    expect(replay, 1);
    expect(retry, 2);
    expect(rearm, 1);
  });
}
