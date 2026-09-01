import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/pre_prayer_alert_scheduler.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';

void main() {
  test('CastFailureNotificationCopy maps FAILED_NO_TARGET in Indonesian', () {
    final copy = CastFailureNotificationCopy.forOutcome(
      outcomeCode: Outcome.failedNoTarget.code,
      prayerName: 'maghrib',
      isId: true,
    );
    expect(copy.title, contains('Maghrib'));
    expect(copy.body, contains('WiFi'));
  });

  test('prePrayerDisplayName returns English names', () {
    expect(prePrayerDisplayName('fajr', isId: false), 'Fajr');
    expect(
      PrayerDeliveryCoordinator.canonicalPrayerName('isha-dryrun'),
      'isha',
    );
  });
}
