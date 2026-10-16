import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

/// Decides when adhkar reminders should fire for a day's prayer times.
abstract class AdhkarScheduler {
  const AdhkarScheduler._();

  const factory AdhkarScheduler(AdhkarPrefs prefs, {PrayerPrefs? prayerPrefs}) =
      PrayerTimeAdhkarScheduler;

  /// Reminder time for [type]: the anchoring prayer plus the effective offset.
  ///
  /// Offset is the user delay. When iqamah is enabled for that prayer, the
  /// offset is at least iqamah minutes + 10. A null [PrayerPrefs] means
  /// iqamah is off, so the offset stays the delay.
  DateTime calculateAdhkarTime(AdhkarType type, DateTime prayerTime);

  /// Reminder times for enabled adhkar, keyed by type. [prayerTimes] uses
  /// lowercase keys: `fajr`, `dhuhr`, `asr`, `isha`.
  Map<AdhkarType, DateTime> getScheduledAdhkar(
    Map<String, DateTime> prayerTimes,
  );

  /// True when [adhkarTime] is past, or too close to, [deadline].
  bool shouldSkipAdhkar(DateTime adhkarTime, DateTime deadline);
}

/// Morning adhkar: after Fajr + offset, valid until Dhuhr.
/// Evening adhkar: after Asr + offset, valid until Isha.
final class PrayerTimeAdhkarScheduler extends AdhkarScheduler {
  const PrayerTimeAdhkarScheduler(AdhkarPrefs prefs, {PrayerPrefs? prayerPrefs})
    : _prefs = prefs,
      _prayerPrefs = prayerPrefs,
      super._();

  static const minimumLeadBeforeDeadline = Duration(minutes: 30);

  /// Extra minutes after iqamah before adhkar may start.
  static const iqamahBuffer = 10;

  final AdhkarPrefs _prefs;
  final PrayerPrefs? _prayerPrefs;

  static const _anchorKey = {
    AdhkarType.morning: 'fajr',
    AdhkarType.evening: 'asr',
  };
  static const _deadlineKey = {
    AdhkarType.morning: 'dhuhr',
    AdhkarType.evening: 'isha',
  };
  static const _iqamahKey = {
    AdhkarType.morning: 'fajr',
    AdhkarType.evening: 'asr',
  };

  /// True when the iqamah floor is later than the user's delay.
  bool iqamahOffsetWins(AdhkarType type) {
    final iqamah = _iqamahMinutes(type);
    if (iqamah <= 0) return false;
    return iqamah + iqamahBuffer > _prefs.delayMinutes(type);
  }

  int offsetMinutes(AdhkarType type) {
    final delay = _prefs.delayMinutes(type);
    final iqamah = _iqamahMinutes(type);
    if (iqamah <= 0) return delay;
    final floor = iqamah + iqamahBuffer;
    return delay > floor ? delay : floor;
  }

  int _iqamahMinutes(AdhkarType type) {
    final prefs = _prayerPrefs;
    if (prefs == null) return 0;
    return prefs.iqamahMinutesFor(_iqamahKey[type]!);
  }

  @override
  DateTime calculateAdhkarTime(AdhkarType type, DateTime prayerTime) {
    return prayerTime.add(Duration(minutes: offsetMinutes(type)));
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
