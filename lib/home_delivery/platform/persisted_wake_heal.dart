/// Same decision [BootReceiver] / [AlarmHealWorker] use on Android.
///
/// Unacked real pending fire → replay that delivery (do not arm a
/// [reschedule-retry] that would overwrite the pending payload).
/// Future persisted epoch → re-arm that wake.
/// Past or missing epoch → [armRescheduleRetry] (the native function,
/// not a copy of its AlarmClock math).
enum PersistedWakeHealAction {
  replayPendingFire,
  rearmFromPrefs,
  armRescheduleRetry,
}

/// Synthetic wake name used only to boot Dart for reschedule — never a
/// real prayer delivery.
const String kRescheduleRetryPrayer = 'reschedule-retry';

/// True when [prayer] is an unacked delivery that must be replayed on heal.
bool isRealPendingPrayer(String? prayer) {
  if (prayer == null || prayer.isEmpty) return false;
  return prayer != kRescheduleRetryPrayer;
}

/// Which heal path to run for the SharedPreferences BootReceiver reads.
PersistedWakeHealAction persistedWakeHealAction({
  required int? storedEpochMs,
  required int nowMs,
  String? pendingPrayer,
}) {
  if (isRealPendingPrayer(pendingPrayer)) {
    return PersistedWakeHealAction.replayPendingFire;
  }
  if (storedEpochMs != null && storedEpochMs > nowMs) {
    return PersistedWakeHealAction.rearmFromPrefs;
  }
  return PersistedWakeHealAction.armRescheduleRetry;
}

/// Runs the same branch [ExactAlarmPlugin.healPersistedWake] uses.
void runPersistedWakeHeal({
  required int? storedEpochMs,
  required int nowMs,
  String? pendingPrayer,
  required void Function() replayPendingFire,
  required void Function() rearmFromPrefs,
  required void Function() armRescheduleRetry,
}) {
  switch (persistedWakeHealAction(
    storedEpochMs: storedEpochMs,
    nowMs: nowMs,
    pendingPrayer: pendingPrayer,
  )) {
    case PersistedWakeHealAction.replayPendingFire:
      replayPendingFire();
    case PersistedWakeHealAction.rearmFromPrefs:
      rearmFromPrefs();
    case PersistedWakeHealAction.armRescheduleRetry:
      armRescheduleRetry();
  }
}
