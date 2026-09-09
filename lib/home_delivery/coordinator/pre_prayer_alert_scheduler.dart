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

/// Notification copy when Cast delivery fails at azan time,
/// or when phone fallback plays instead.
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
          'Speaker tidak ditemukan di WiFi. Buka app dan cek Speaker Setup.',
        'FAILED_NO_ROUTE' =>
          'Tidak ada jalur ke speaker (VPN atau WiFi berbeda). Adhan $prayer tidak diputar.',
        'FAILED_CAST_CONNECT' =>
          'Gagal hubung ke speaker untuk $prayer. Buka app dan coba tes Adhan.',
        'FAILED_LOAD_MEDIA' =>
          'Speaker menolak audio Adhan $prayer. Buka Riwayat Adhan untuk detail.',
        _ => 'Adhan $prayer tidak bisa diputar ke speaker. Buka app untuk detail.',
      };
      return (title: 'Adhan $prayer gagal', body: body);
    }
    final body = switch (outcomeCode) {
      'FAILED_NO_TARGET' =>
        'Saved speaker not found on WiFi. Open the app and check Speaker Setup.',
      'FAILED_NO_ROUTE' =>
        'No route to the speaker (VPN or wrong WiFi). $prayer Adhan was not cast.',
      'FAILED_CAST_CONNECT' =>
        'Could not connect to the speaker for $prayer. Open the app and run a test.',
      'FAILED_LOAD_MEDIA' =>
        'Speaker rejected the $prayer Adhan audio. See Adhan history for details.',
      _ => '$prayer Adhan could not play on the speaker. Open the app for details.',
    };
    return (title: '$prayer Adhan failed', body: body);
  }

  /// Short heads-up when Cast failed and the phone played instead.
  static ({String title, String body}) forPhoneFallback({
    required String outcomeCode,
    required String prayerName,
    required bool fullAdhan,
    required bool isId,
  }) {
    final prayer = prePrayerDisplayName(
      PrayerDeliveryCoordinator.canonicalPrayerName(prayerName),
      isId: isId,
    );
    final reason = _shortReason(outcomeCode, isId: isId);
    if (isId) {
      final action = fullAdhan
          ? 'diputar di ponsel'
          : 'nada singkat (lokasi rumah belum yakin)';
      return (
        title: '$prayer · $reason — $action',
        body: fullAdhan
            ? 'Speaker tidak siap. Adhan $prayer diputar di ponsel.'
            : 'Speaker tidak siap dan lokasi rumah belum yakin — hanya nada singkat.',
      );
    }
    final action = fullAdhan
        ? 'played on phone'
        : 'short chime (home presence uncertain)';
    return (
      title: '$prayer · $reason — $action',
      body: fullAdhan
          ? 'Speaker was unavailable. $prayer Adhan played on this phone.'
          : 'Speaker was unavailable and home presence was uncertain — short chime only.',
    );
  }

  static String _shortReason(String outcomeCode, {required bool isId}) {
    if (isId) {
      return switch (outcomeCode) {
        'FAILED_NO_TARGET' => 'speaker tidak ditemukan',
        'FAILED_NO_ROUTE' => 'tidak ada jalur ke speaker',
        'FAILED_CAST_CONNECT' => 'gagal hubung speaker',
        'FAILED_LOAD_MEDIA' => 'speaker menolak audio',
        _ => 'speaker tidak siap',
      };
    }
    return switch (outcomeCode) {
      'FAILED_NO_TARGET' => 'speaker unreachable',
      'FAILED_NO_ROUTE' => 'no route to speaker',
      'FAILED_CAST_CONNECT' => 'could not connect',
      'FAILED_LOAD_MEDIA' => 'speaker rejected audio',
      _ => 'speaker unavailable',
    };
  }
}
