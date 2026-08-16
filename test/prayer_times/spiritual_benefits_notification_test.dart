import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';

void main() {
  group('SpiritualBenefitsNotification', () {
    test('title is Preparing adzan for real and dry-run', () {
      expect(
        SpiritualBenefitsNotification.title('dhuhr'),
        'Preparing adzan',
      );
      expect(
        SpiritualBenefitsNotification.title('dhuhr-dryrun'),
        'Preparing adzan',
      );
      expect(
        SpiritualBenefitsNotification.title('dhuhr-dryrun', language: 'id'),
        'Menyiapkan adzan',
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
        SpiritualBenefitsNotification.subtitle('dhuhr-dryrun'),
        'Dhuhr (dry-run) · Midday spiritual recharge',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('dhuhr-dryrun'),
        isNot(contains('dhuhr-dryrun')),
      );
      expect(
        SpiritualBenefitsNotification.title('reschedule-retry'),
        'Preparing adzan',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('unknown-dryrun'),
        'Adhan (dry-run)',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('dhuhr'),
        'Dhuhr · Midday spiritual recharge',
      );
    });

    test('maps each canonical prayer on the subtitle', () {
      expect(
        SpiritualBenefitsNotification.subtitle('fajr'),
        'Fajr · Spiritual awakening and consciousness',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('asr'),
        'Asr · Protection from afternoon negligence',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('maghrib'),
        'Maghrib · Gratitude for the day\'s blessings',
      );
      expect(
        SpiritualBenefitsNotification.subtitle('isha'),
        'Isha · Peaceful end to the day',
      );
    });
  });
}
