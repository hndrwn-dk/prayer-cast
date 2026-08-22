import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/persisted_wake_heal.dart';

void main() {
  group('persistedWakeHealAction', () {
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

  test('past or missing epoch calls armRescheduleRetry', () {
    var rearm = 0;
    var retry = 0;
    void rearmFromPrefs() => rearm++;
    void armRescheduleRetry() => retry++;

    runPersistedWakeHeal(
      storedEpochMs: 100,
      nowMs: 200,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: null,
      nowMs: 200,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );
    runPersistedWakeHeal(
      storedEpochMs: 400,
      nowMs: 200,
      rearmFromPrefs: rearmFromPrefs,
      armRescheduleRetry: armRescheduleRetry,
    );

    expect(retry, 2);
    expect(rearm, 1);
  });
}
