import '../delivery/delivery_timing.dart';

/// Whether a failed delivery may still be retried from history.
///
/// Window = prayer valid delivery deadline ([DeliveryTiming.deadline]) or
/// 30 minutes after the failure fire (or scheduled azan if no fire),
/// whichever ends sooner.
abstract final class DeliveryRetryWindow {
  static const Duration maxAfterFailure = Duration(minutes: 30);

  static DateTime deadline({
    required DateTime scheduledAzan,
    DateTime? firedAt,
    DateTime? nextPrayerWake,
  }) {
    final prayerEnd = DeliveryTiming.deadline(
      scheduledAzan: scheduledAzan,
      nextPrayerWake: nextPrayerWake,
    );
    final failureAnchor = firedAt ?? scheduledAzan;
    final capEnd = failureAnchor.add(maxAfterFailure);
    return prayerEnd.isBefore(capEnd) ? prayerEnd : capEnd;
  }

  static bool canRetry({
    required DateTime scheduledAzan,
    required DateTime now,
    DateTime? firedAt,
    DateTime? nextPrayerWake,
  }) {
    return !now.isAfter(
      deadline(
        scheduledAzan: scheduledAzan,
        firedAt: firedAt,
        nextPrayerWake: nextPrayerWake,
      ),
    );
  }

  /// Short reason when [canRetry] is false (for a disabled Retry button).
  static String disabledReason({
    required DateTime scheduledAzan,
    required DateTime now,
    required bool isId,
    DateTime? firedAt,
    DateTime? nextPrayerWake,
  }) {
    if (canRetry(
      scheduledAzan: scheduledAzan,
      now: now,
      firedAt: firedAt,
      nextPrayerWake: nextPrayerWake,
    )) {
      return '';
    }
    return isId
        ? 'Jendela waktu sholat sudah lewat'
        : 'Prayer window has ended';
  }
}
