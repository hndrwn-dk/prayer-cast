import '../../prayer_times/prayer_prefs.dart';
import '../platform/exact_alarm.dart';
import 'next_prayer_provider.dart';
import 'prayer_delivery_coordinator.dart';

String prePrayerDisplayName(String key, {required bool isId}) {
  if (isId) {
    return switch (key) {
      'fajr' => 'Subuh',
      'dhuhr' => 'Dzuhur',
      'asr' => 'Asar',
      'maghrib' => 'Maghrib',
      'isha' => 'Isya',
      _ => key,
    };
  }
  return switch (key) {
    'fajr' => 'Fajr',
    'dhuhr' => 'Dhuhr',
    'asr' => 'Asr',
    'maghrib' => 'Maghrib',
    'isha' => 'Isha',
    _ => key,
  };
}

/// Schedules / cancels the lightweight pre-prayer reminder alarm.
final class PrePrayerAlertScheduler {
  PrePrayerAlertScheduler({
    required ExactAlarmPlatform exactAlarm,
    required PrayerPrefsStore prayerPrefs,
    required Future<String?> Function() readLocaleCode,
  })  : _exactAlarm = exactAlarm,
        _prayerPrefs = prayerPrefs,
        _readLocaleCode = readLocaleCode;

  final ExactAlarmPlatform _exactAlarm;
  final PrayerPrefsStore _prayerPrefs;
  final Future<String?> Function() _readLocaleCode;

  /// Arm or cancel the next pre-alert alongside the main wake schedule.
  Future<void> syncForPrayer(NextPrayer prayer, DateTime now) async {
    final prefs = await _prayerPrefs.read();
    final minutes = prefs.prePrayerAlertMinutes;
    if (minutes <= 0) {
      await _exactAlarm.cancelPreAlert();
      return;
    }

    final alertAt = prayer.scheduledAt.subtract(Duration(minutes: minutes));
    if (!alertAt.isAfter(now)) {
      await _exactAlarm.cancelPreAlert();
      return;
    }

    final localeCode = await _readLocaleCode();
    final isId = localeCode != 'en';
    final prayerKey =
        PrayerDeliveryCoordinator.canonicalPrayerName(prayer.name);
    final displayName = prePrayerDisplayName(prayerKey, isId: isId);
    final title = isId
        ? '$minutes menit lagi $displayName'
        : '$displayName in $minutes minutes';
    final body = isId
        ? 'Yuk bersiap — ambil wudhu dan siapkan diri untuk sholat $displayName.'
        : 'Get ready — make wudu and prepare for $displayName prayer.';

    await _exactAlarm.schedulePreAlert(
      epochMs: alertAt.millisecondsSinceEpoch,
      title: title,
      body: body,
      sound: prefs.prePrayerAlertSound.wire,
    );
  }

  Future<void> cancel() => _exactAlarm.cancelPreAlert();
}

/// Notification copy when Cast delivery fails at azan time.
abstract final class CastFailureNotificationCopy {
  static ({String title, String body}) forOutcome({
    required String outcomeCode,
    required String prayerName,
    required bool isId,
  }) {
    final prayer = prePrayerDisplayName(
      PrayerDeliveryCoordinator.canonicalPrayerName(prayerName),
      isId: isId,
    );
    if (isId) {
      final body = switch (outcomeCode) {
        'FAILED_NO_TARGET' =>
          'Speaker "$prayer" tidak ditemukan di WiFi. Buka app dan cek Speaker Setup.',
        'FAILED_NO_ROUTE' =>
          'Tidak ada jalur ke speaker (VPN atau WiFi berbeda). Adzan $prayer tidak diputar.',
        'FAILED_CAST_CONNECT' =>
          'Gagal hubung ke speaker untuk $prayer. Buka app dan coba tes adzan.',
        'FAILED_LOAD_MEDIA' =>
          'Speaker menolak audio adzan $prayer. Buka Riwayat pengiriman untuk detail.',
        _ => 'Adzan $prayer tidak bisa diputar ke speaker. Buka app untuk detail.',
      };
      return (title: 'Adzan $prayer gagal', body: body);
    }
    final body = switch (outcomeCode) {
      'FAILED_NO_TARGET' =>
        'Saved speaker not found on WiFi. Open the app and check Speaker Setup.',
      'FAILED_NO_ROUTE' =>
        'No route to the speaker (VPN or wrong WiFi). $prayer adzan was not cast.',
      'FAILED_CAST_CONNECT' =>
        'Could not connect to the speaker for $prayer. Open the app and run a test.',
      'FAILED_LOAD_MEDIA' =>
        'Speaker rejected the $prayer adzan audio. See Delivery log for details.',
      _ => '$prayer adzan could not play on the speaker. Open the app for details.',
    };
    return (title: '$prayer adzan failed', body: body);
  }
}
