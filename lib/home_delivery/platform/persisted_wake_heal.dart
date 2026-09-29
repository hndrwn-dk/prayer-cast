/// Same decision [BootReceiver] / [AlarmHealWorker] use on Android.
///
/// Unacked real pending fire → replay that delivery (do not arm a
/// [reschedule-retry] that would overwrite the pending payload).
/// Future persisted epoch → re-arm that wake.
/// Past epoch still within azan delivery grace → fire that overdue wake
/// (do not jump to reschedule-retry while azan is still upcoming).
/// Past grace or missing epoch → [armRescheduleRetry] (the native function,
/// not a copy of its AlarmClock math).
enum PersistedWakeHealAction {
  replayPendingFire,
  rearmFromPrefs,
  fireOverduePrefs,
  armRescheduleRetry,
}

/// Synthetic wake name used only to boot Dart for reschedule — never a
/// real prayer delivery.
const String kRescheduleRetryPrayer = 'reschedule-retry';

/// Wake is T−120; azan is wake + 2 minutes. Match native
/// `OVERDUE_DELIVERY_GRACE_MS` / [DeliveryTiming.graceAfterAzan].
const Duration kOverdueDeliveryGrace = Duration(minutes: 5);

const Duration kWakeLeadBeforeAzan = Duration(seconds: 120);

/// True when [prayer] is an unacked delivery that must be replayed on heal.
bool isRealPendingPrayer(String? prayer) {
  if (prayer == null || prayer.isEmpty) return false;
  return prayer != kRescheduleRetryPrayer;
}

/// True when a past wake epoch can still start delivery (before azan+grace).
bool isOverdueWakeStillEligible({
  required int storedEpochMs,
  required int nowMs,
  required String? prayer,
}) {
  if (!isRealPendingPrayer(prayer)) return false;
  if (storedEpochMs <= 0 || storedEpochMs > nowMs) return false;
  final azanEpochMs = storedEpochMs + kWakeLeadBeforeAzan.inMilliseconds;
  return nowMs <= azanEpochMs + kOverdueDeliveryGrace.inMilliseconds;
}

/// Which heal path to run for the SharedPreferences BootReceiver reads.
PersistedWakeHealAction persistedWakeHealAction({
  required int? storedEpochMs,
  required int nowMs,
  String? pendingPrayer,
  String? storedPrayer,
}) {
  if (isRealPendingPrayer(pendingPrayer)) {
    return PersistedWakeHealAction.replayPendingFire;
  }
  if (storedEpochMs != null && storedEpochMs > nowMs) {
    return PersistedWakeHealAction.rearmFromPrefs;
  }
  if (storedEpochMs != null &&
      isOverdueWakeStillEligible(
        storedEpochMs: storedEpochMs,
        nowMs: nowMs,
        prayer: storedPrayer,
      )) {
    return PersistedWakeHealAction.fireOverduePrefs;
  }
  return PersistedWakeHealAction.armRescheduleRetry;
}

/// Runs the same branch [ExactAlarmPlugin.healPersistedWake] uses.
void runPersistedWakeHeal({
  required int? storedEpochMs,
  required int nowMs,
  String? pendingPrayer,
  String? storedPrayer,
  required void Function() replayPendingFire,
  required void Function() rearmFromPrefs,
  required void Function() fireOverduePrefs,
  required void Function() armRescheduleRetry,
}) {
  switch (persistedWakeHealAction(
    storedEpochMs: storedEpochMs,
    nowMs: nowMs,
    pendingPrayer: pendingPrayer,
    storedPrayer: storedPrayer,
  )) {
    case PersistedWakeHealAction.replayPendingFire:
      replayPendingFire();
    case PersistedWakeHealAction.rearmFromPrefs:
      rearmFromPrefs();
    case PersistedWakeHealAction.fireOverduePrefs:
      fireOverduePrefs();
    case PersistedWakeHealAction.armRescheduleRetry:
      armRescheduleRetry();
  }
}
