import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_scheduler.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

/// Arms or cancels the next morning and evening adhkar alarms.
///
/// Called when the app starts, when the prayer schedule or city changes,
/// when auto-play or the delay changes, and after an adhkar alarm fires.
final class AdhkarAlarmSync {
  AdhkarAlarmSync({
    required AdhkarPrefs adhkarPrefs,
    required ExactAlarmPlatform alarm,
    required Future<PrayerPrefs> Function() readPrayerPrefs,
    required Future<Map<String, DateTime>?> Function(DateTime day)
    readPrayerTimes,
    DateTime Function()? clock,
  }) : _adhkarPrefs = adhkarPrefs,
       _alarm = alarm,
       _readPrayerPrefs = readPrayerPrefs,
       _readPrayerTimes = readPrayerTimes,
       _clock = clock ?? DateTime.now;

  final AdhkarPrefs _adhkarPrefs;
  final ExactAlarmPlatform _alarm;
  final Future<PrayerPrefs> Function() _readPrayerPrefs;
  final Future<Map<String, DateTime>?> Function(DateTime day) _readPrayerTimes;
  final DateTime Function() _clock;

  /// How many upcoming days to search for a playable slot.
  static const lookaheadDays = 3;

  Future<void> sync() async {
    final now = _clock();
    final prayerPrefs = await _readPrayerPrefs();
    final scheduler = PrayerTimeAdhkarScheduler(
      _adhkarPrefs,
      prayerPrefs: prayerPrefs,
    );
    for (final type in AdhkarType.values) {
      if (!_adhkarPrefs.enabled(type)) {
        await _alarm.cancelAdhkar(type.name);
        continue;
      }
      final at = await _nextPlayable(scheduler, type, now);
      if (at == null) {
        await _alarm.cancelAdhkar(type.name);
        continue;
      }
      await _alarm.scheduleAdhkar(
        type: type.name,
        atMs: at.millisecondsSinceEpoch,
      );
    }
  }

  Future<DateTime?> _nextPlayable(
    PrayerTimeAdhkarScheduler scheduler,
    AdhkarType type,
    DateTime now,
  ) async {
    final start = DateTime(now.year, now.month, now.day);
    for (var day = 0; day < lookaheadDays; day++) {
      final date = start.add(Duration(days: day));
      final Map<String, DateTime>? times;
      try {
        times = await _readPrayerTimes(date);
      } catch (_) {
        continue;
      }
      if (times == null) continue;
      final at = scheduler.getScheduledAdhkar(times)[type];
      if (at != null && at.isAfter(now)) return at;
    }
    return null;
  }
}
