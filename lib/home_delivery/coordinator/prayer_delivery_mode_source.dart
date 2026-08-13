import '../../prayer_times/prayer_prefs.dart';

/// Looks up the per-prayer delivery mode at alarm-fire time.
abstract interface class PrayerDeliveryModeSource {
  Future<PrayerDeliveryMode> modeFor(String prayerName);
}

/// Default: every prayer casts. Used when prefs are not wired (tests).
final class AlwaysCastDeliveryModeSource implements PrayerDeliveryModeSource {
  const AlwaysCastDeliveryModeSource();

  @override
  Future<PrayerDeliveryMode> modeFor(String prayerName) async =>
      PrayerDeliveryMode.cast;
}

/// Reads [PrayerPrefs.deliveryFor] so a mode change applies to the next fire
/// without re-arming the alarm payload.
final class PrefsPrayerDeliveryModeSource implements PrayerDeliveryModeSource {
  PrefsPrayerDeliveryModeSource(this._store);

  final PrayerPrefsStore _store;

  @override
  Future<PrayerDeliveryMode> modeFor(String prayerName) async {
    return (await _store.read()).deliveryFor(prayerName);
  }
}
