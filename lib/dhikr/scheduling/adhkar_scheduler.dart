import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';

/// Decides when adhkar reminders should fire for a day's prayer times.
abstract class AdhkarScheduler {
  const AdhkarScheduler._();

  const factory AdhkarScheduler(AdhkarPrefs prefs) = PrayerTimeAdhkarScheduler;

  /// Reminder time for [type]: the anchoring prayer time plus the user delay.
  DateTime calculateAdhkarTime(AdhkarType type, DateTime prayerTime);

  /// Reminder times for enabled adhkar, keyed by type. [prayerTimes] uses
  /// lowercase keys: `fajr`, `dhuhr`, `asr`, `isha`.
  Map<AdhkarType, DateTime> getScheduledAdhkar(
    Map<String, DateTime> prayerTimes,
  );

  /// True when [adhkarTime] is past, or too close to, [deadline].
  bool shouldSkipAdhkar(DateTime adhkarTime, DateTime deadline);
}

/// Morning adhkar: after Fajr + delay, valid until Dhuhr.
/// Evening adhkar: after Asr + delay, valid until Isha.
final class PrayerTimeAdhkarScheduler extends AdhkarScheduler {
  const PrayerTimeAdhkarScheduler(this._prefs) : super._();

  static const minimumLeadBeforeDeadline = Duration(minutes: 30);

  final AdhkarPrefs _prefs;

  static const _anchorKey = {
    AdhkarType.morning: 'fajr',
    AdhkarType.evening: 'asr',
  };
  static const _deadlineKey = {
    AdhkarType.morning: 'dhuhr',
    AdhkarType.evening: 'isha',
  };

  @override
  DateTime calculateAdhkarTime(AdhkarType type, DateTime prayerTime) {
    return prayerTime.add(Duration(minutes: _prefs.delayMinutes(type)));
  }

  @override
  Map<AdhkarType, DateTime> getScheduledAdhkar(
    Map<String, DateTime> prayerTimes,
  ) {
    final scheduled = <AdhkarType, DateTime>{};
    for (final type in AdhkarType.values) {
      if (!_prefs.enabled(type)) continue;
      final anchor = prayerTimes[_anchorKey[type]];
      if (anchor == null) continue;
      final time = calculateAdhkarTime(type, anchor);
      final deadline = prayerTimes[_deadlineKey[type]];
      if (deadline != null && shouldSkipAdhkar(time, deadline)) continue;
      scheduled[type] = time;
    }
    return scheduled;
  }

  @override
  bool shouldSkipAdhkar(DateTime adhkarTime, DateTime deadline) {
    return deadline.difference(adhkarTime) < minimumLeadBeforeDeadline;
  }
}
