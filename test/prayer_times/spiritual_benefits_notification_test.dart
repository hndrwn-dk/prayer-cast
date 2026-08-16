import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';

void main() {
  group('SpiritualBenefitsNotification', () {
    test('strips dry-run suffix and maps prayer to EN teaser title', () {
      expect(
        SpiritualBenefitsNotification.title('dhuhr'),
        'Dhuhr · Midday spiritual recharge',
      );
      expect(
        SpiritualBenefitsNotification.title('dhuhr-dryrun'),
        'Dhuhr (dry-run)',
      );
      expect(
        SpiritualBenefitsNotification.canonicalPrayer('dhuhr-dryrun'),
        'dhuhr',
      );
      expect(SpiritualBenefitsNotification.isDryRun('dhuhr-dryrun'), isTrue);
      expect(SpiritualBenefitsNotification.isDryRun('dhuhr'), isFalse);
    });

    test('never returns a raw key like dhuhr-dryrun', () {
      expect(
        SpiritualBenefitsNotification.title('dhuhr-dryrun'),
        isNot(contains('dhuhr-dryrun')),
      );
      expect(
        SpiritualBenefitsNotification.title('reschedule-retry'),
        'Adhan',
      );
      expect(
        SpiritualBenefitsNotification.title('unknown-dryrun'),
        'Adhan (dry-run)',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('dhuhr-dryrun'),
        'Dhuhr · Midday spiritual recharge',
      );
    });

    test('maps each canonical prayer', () {
      expect(
        SpiritualBenefitsNotification.title('fajr'),
        'Fajr · Spiritual awakening and consciousness',
      );
      expect(
        SpiritualBenefitsNotification.title('asr'),
        'Asr · Protection from afternoon negligence',
      );
      expect(
        SpiritualBenefitsNotification.title('maghrib'),
        'Maghrib · Gratitude for the day\'s blessings',
      );
      expect(
        SpiritualBenefitsNotification.title('isha'),
        'Isha · Peaceful end to the day',
      );
    });
  });
}
