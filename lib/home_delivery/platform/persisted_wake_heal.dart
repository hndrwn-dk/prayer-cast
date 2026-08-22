/// Same decision [BootReceiver] / [AlarmHealWorker] use on Android.
///
/// Future persisted epoch → re-arm that wake.
/// Past or missing epoch → [armRescheduleRetry] (the native function,
/// not a copy of its AlarmClock math).
enum PersistedWakeHealAction {
  rearmFromPrefs,
  armRescheduleRetry,
}

/// Which heal path to run for the SharedPreferences epoch BootReceiver reads.
PersistedWakeHealAction persistedWakeHealAction({
  required int? storedEpochMs,
  required int nowMs,
}) {
  if (storedEpochMs != null && storedEpochMs > nowMs) {
    return PersistedWakeHealAction.rearmFromPrefs;
  }
  return PersistedWakeHealAction.armRescheduleRetry;
}

/// Runs [rearmFromPrefs] or [armRescheduleRetry] using the same branch
/// [ExactAlarmPlugin.healPersistedWake] uses.
void runPersistedWakeHeal({
  required int? storedEpochMs,
  required int nowMs,
  required void Function() rearmFromPrefs,
  required void Function() armRescheduleRetry,
}) {
  switch (persistedWakeHealAction(
    storedEpochMs: storedEpochMs,
    nowMs: nowMs,
  )) {
    case PersistedWakeHealAction.rearmFromPrefs:
      rearmFromPrefs();
    case PersistedWakeHealAction.armRescheduleRetry:
      armRescheduleRetry();
  }
}
