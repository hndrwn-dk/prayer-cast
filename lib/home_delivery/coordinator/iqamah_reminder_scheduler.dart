import '../../prayer_times/prayer_prefs.dart';
import '../platform/exact_alarm.dart';
import 'next_prayer_provider.dart';
import 'pre_prayer_alert_scheduler.dart';
import 'prayer_delivery_coordinator.dart';

/// Schedules the post-adhan iqamah nudge (phone notification only).
final class IqamahReminderScheduler {
  IqamahReminderScheduler({
    required ExactAlarmPlatform exactAlarm,
    required PrayerPrefsStore prayerPrefs,
    required Future<String?> Function() readLocaleCode,
  })  : _exactAlarm = exactAlarm,
        _prayerPrefs = prayerPrefs,
        _readLocaleCode = readLocaleCode;

  final ExactAlarmPlatform _exactAlarm;
  final PrayerPrefsStore _prayerPrefs;
  final Future<String?> Function() _readLocaleCode;

  /// Arm or cancel the next iqamah nudge for [prayer].
  Future<void> syncForPrayer(NextPrayer prayer, DateTime now) async {
    final prefs = await _prayerPrefs.read();
    final prayerKey =
        PrayerDeliveryCoordinator.canonicalPrayerName(prayer.name);
    final minutes = prefs.iqamahMinutesFor(prayerKey);
    if (minutes <= 0) {
      await _exactAlarm.cancelIqamahReminder();
      return;
    }

    final alertAt = prayer.scheduledAt.add(Duration(minutes: minutes));
    if (!alertAt.isAfter(now)) {
      await _exactAlarm.cancelIqamahReminder();
      return;
    }

    final localeCode = await _readLocaleCode();
    final isId = localeCode != 'en';
    final displayName = prePrayerDisplayName(prayerKey, isId: isId);
    final title = isId
        ? 'Waktunya sholat $displayName'
        : 'Time for $displayName prayer';
    final body = isId
        ? 'Iqamah — berdiri untuk sholat $displayName.'
        : 'Iqamah — stand for $displayName prayer.';

    await _exactAlarm.scheduleIqamahReminder(
      epochMs: alertAt.millisecondsSinceEpoch,
      title: title,
      body: body,
      prayer: prayerKey,
      sound: prefs.iqamahSound.wire,
    );
  }

  /// After a prayer fires, keep that prayer's iqamah if it is still upcoming;
  /// only then fall through to arm the next prayer's nudge.
  Future<void> syncAfterDelivery({
    required NextPrayer delivered,
    required NextPrayer next,
    required DateTime now,
  }) async {
    final prefs = await _prayerPrefs.read();
    final deliveredKey =
        PrayerDeliveryCoordinator.canonicalPrayerName(delivered.name);
    final minutes = prefs.iqamahMinutesFor(deliveredKey);
    if (minutes > 0) {
      final alertAt = delivered.scheduledAt.add(Duration(minutes: minutes));
      if (alertAt.isAfter(now)) {
        await syncForPrayer(delivered, now);
        return;
      }
    }
    await syncForPrayer(next, now);
  }

  Future<void> cancel() => _exactAlarm.cancelIqamahReminder();
}
