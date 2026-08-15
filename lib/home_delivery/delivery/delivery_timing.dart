/// Wall-clock eligibility for starting adhan after a wake (spec §5.5 / §6.2).
///
/// Native `firedAt` is when [AlarmManager] ran, not when Dart started. A
/// BAL-blocked activity leaves `pendingFire` in memory; opening the app
/// 50 minutes later still looks "on time" if we only compare firedAt to
/// T−120. Eligibility must use [now] versus scheduled azan.
abstract final class DeliveryTiming {
  /// Play only until this long after azan — long enough for T−120 wake +
  /// presence + a short BAL delay, short enough that opening the app long
  /// after azan must not blast the speaker.
  static const Duration graceAfterAzan = Duration(minutes: 5);

  /// Last instant [now] may start delivery for [scheduledAzan].
  ///
  /// Caps at [nextPrayerWake] (next slot's T−120) when that is sooner, so a
  /// close following prayer is never overlapped.
  static DateTime deadline({
    required DateTime scheduledAzan,
    DateTime? nextPrayerWake,
  }) {
    final graceEnd = scheduledAzan.add(graceAfterAzan);
    if (nextPrayerWake != null && nextPrayerWake.isBefore(graceEnd)) {
      return nextPrayerWake;
    }
    return graceEnd;
  }

  /// True when [now] is past [deadline] — do not Cast or play locally.
  static bool isTooLate({
    required DateTime scheduledAzan,
    required DateTime now,
    DateTime? nextPrayerWake,
  }) {
    return now.isAfter(
      deadline(scheduledAzan: scheduledAzan, nextPrayerWake: nextPrayerWake),
    );
  }
}
