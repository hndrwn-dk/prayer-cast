import 'package:prayer_cast/l10n/app_localizations.dart';

/// Localized spiritual-benefits copy for one canonical prayer.
final class SpiritualBenefits {
  const SpiritualBenefits({
    required this.prayerKey,
    required this.teaser,
    required this.benefits,
    required this.sunnah,
    required this.asideKind,
    required this.aside,
  });

  final String prayerKey;
  final String teaser;
  final List<String> benefits;
  final List<String> sunnah;
  final SpiritualAsideKind asideKind;
  final String aside;

  static const Set<String> supported = {
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  };

  static bool isSupported(String prayer) =>
      supported.contains(SpiritualBenefitsNotification.canonicalPrayer(prayer));

  /// Null when [prayer] is not a five-daily slot (e.g. `reschedule-retry`).
  static SpiritualBenefits? of(AppLocalizations l10n, String prayer) {
    final key = SpiritualBenefitsNotification.canonicalPrayer(prayer);
    return switch (key) {
      'fajr' => SpiritualBenefits(
          prayerKey: key,
          teaser: l10n.fajrTeaser,
          benefits: [
            l10n.fajrBenefit1,
            l10n.fajrBenefit2,
            l10n.fajrBenefit3,
            l10n.fajrBenefit4,
          ],
          sunnah: [
            l10n.fajrSunnah1,
            l10n.fajrSunnah2,
            l10n.fajrSunnah3,
            l10n.fajrSunnah4,
          ],
          asideKind: SpiritualAsideKind.saying,
          aside: l10n.fajrSaying,
        ),
      'dhuhr' => SpiritualBenefits(
          prayerKey: key,
          teaser: l10n.dhuhrTeaser,
          benefits: [
            l10n.dhuhrBenefit1,
            l10n.dhuhrBenefit2,
            l10n.dhuhrBenefit3,
            l10n.dhuhrBenefit4,
          ],
          sunnah: [
            l10n.dhuhrSunnah1,
            l10n.dhuhrSunnah2,
            l10n.dhuhrSunnah3,
            l10n.dhuhrSunnah4,
          ],
          asideKind: SpiritualAsideKind.note,
          aside: l10n.dhuhrNote,
        ),
      'asr' => SpiritualBenefits(
          prayerKey: key,
          teaser: l10n.asrTeaser,
          benefits: [
            l10n.asrBenefit1,
            l10n.asrBenefit2,
            l10n.asrBenefit3,
            l10n.asrBenefit4,
          ],
          sunnah: [
            l10n.asrSunnah1,
            l10n.asrSunnah2,
            l10n.asrSunnah3,
            l10n.asrSunnah4,
          ],
          asideKind: SpiritualAsideKind.note,
          aside: l10n.asrNote,
        ),
      'maghrib' => SpiritualBenefits(
          prayerKey: key,
          teaser: l10n.maghribTeaser,
          benefits: [
            l10n.maghribBenefit1,
            l10n.maghribBenefit2,
            l10n.maghribBenefit3,
            l10n.maghribBenefit4,
          ],
          sunnah: [
            l10n.maghribSunnah1,
            l10n.maghribSunnah2,
            l10n.maghribSunnah3,
            l10n.maghribSunnah4,
          ],
          asideKind: SpiritualAsideKind.note,
          aside: l10n.maghribNote,
        ),
      'isha' => SpiritualBenefits(
          prayerKey: key,
          teaser: l10n.ishaTeaser,
          benefits: [
            l10n.ishaBenefit1,
            l10n.ishaBenefit2,
            l10n.ishaBenefit3,
            l10n.ishaBenefit4,
          ],
          sunnah: [
            l10n.ishaSunnah1,
            l10n.ishaSunnah2,
            l10n.ishaSunnah3,
            l10n.ishaSunnah4,
          ],
          asideKind: SpiritualAsideKind.note,
          aside: l10n.ishaNote,
        ),
      _ => null,
    };
  }
}

enum SpiritualAsideKind { saying, note }

/// EN shade-title helper mirroring [SpiritualBenefitsTeaser] in Kotlin.
///
/// Notification copy is built natively at T−120, before Dart. This map
/// stays in lockstep with the Kotlin EN teasers so tests can assert
/// dry-run stripping without a device.
abstract final class SpiritualBenefitsNotification {
  static const String dryRunSuffix = '-dryrun';

  static const Map<String, ({String name, String teaser, List<String> lines})>
      _en = {
    'fajr': (
      name: 'Fajr',
      teaser: 'Spiritual awakening and consciousness',
      lines: [
        'Blessed time for remembrance and reflection',
        'Protection throughout the day',
        'Spiritual awakening and consciousness',
      ],
    ),
    'dhuhr': (
      name: 'Dhuhr',
      teaser: 'Midday spiritual recharge',
      lines: [
        'Break from worldly activities',
        'Midday spiritual recharge',
        'Connection with the community',
      ],
    ),
    'asr': (
      name: 'Asr',
      teaser: 'Protection from afternoon negligence',
      lines: [
        'Protection from afternoon negligence',
        'Preparation for evening',
        'Strengthening of faith',
      ],
    ),
    'maghrib': (
      name: 'Maghrib',
      teaser: 'Gratitude for the day\'s blessings',
      lines: [
        'Gratitude for the day\'s blessings',
        'Family gathering time',
        'Breaking of the fast (if fasting)',
      ],
    ),
    'isha': (
      name: 'Isha',
      teaser: 'Peaceful end to the day',
      lines: [
        'Completion of daily prayers',
        'Peaceful end to the day',
        'Preparation for rest',
      ],
    ),
  };

  static String canonicalPrayer(String prayer) {
    if (prayer.endsWith(dryRunSuffix)) {
      return prayer.substring(0, prayer.length - dryRunSuffix.length);
    }
    return prayer;
  }

  static bool isDryRun(String prayer) => prayer.endsWith(dryRunSuffix);

  /// Collapsed notification title. Never returns a raw key like `dhuhr-dryrun`.
  static String title(String prayer) {
    final key = canonicalPrayer(prayer);
    final copy = _en[key];
    if (copy == null) {
      return isDryRun(prayer) ? 'Adhan (dry-run)' : 'Adhan';
    }
    if (isDryRun(prayer)) return '${copy.name} (dry-run)';
    return '${copy.name} · ${copy.teaser}';
  }

  /// Optional collapsed subtitle (dry-run keeps the teaser visible).
  static String? subtitle(String prayer) {
    if (!isDryRun(prayer)) return null;
    final copy = _en[canonicalPrayer(prayer)];
    if (copy == null) return null;
    return '${copy.name} · ${copy.teaser}';
  }

  static String bigText(String prayer) {
    final copy = _en[canonicalPrayer(prayer)];
    if (copy == null) return title(prayer);
    return copy.lines.take(3).join('\n');
  }
}
