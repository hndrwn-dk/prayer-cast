import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_timing.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_retry_window.dart';

void main() {
  test('retry window is min of prayer grace and 30 minutes after fire', () {
    final azan = DateTime(2026, 9, 9, 16, 0);
    final fired = azan.add(const Duration(minutes: 1));
    final end = DeliveryRetryWindow.deadline(
      scheduledAzan: azan,
      firedAt: fired,
    );
    // Grace is 5m after azan; 30m after fire is later → grace wins.
    expect(end, azan.add(DeliveryTiming.graceAfterAzan));
  });

  test('retry disabled outside window with reason', () {
    final azan = DateTime(2026, 9, 9, 16, 0);
    final late = azan.add(const Duration(hours: 5));
    expect(
      DeliveryRetryWindow.canRetry(scheduledAzan: azan, now: late),
      isFalse,
    );
    expect(
      DeliveryRetryWindow.disabledReason(
        scheduledAzan: azan,
        now: late,
        isId: false,
      ),
      contains('ended'),
    );
  });
}
