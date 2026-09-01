import 'package:geolocator/geolocator.dart';

import '../home_delivery/platform/exact_alarm.dart';
import 'location_resolver.dart';
import 'prayer_prefs.dart';

/// Refreshes prayer-city prefs when the phone has moved ~25 km.
final class TravelScheduleRefresher {
  TravelScheduleRefresher({
    required PrayerPrefsStore store,
    required LocationResolving location,
    required ExactAlarmPlatform exactAlarm,
    this.onPrefsChanged,
    this.moveThresholdMeters = 25000,
  })  : _store = store,
        _location = location,
        _exactAlarm = exactAlarm;

  final PrayerPrefsStore _store;
  final LocationResolving _location;
  final ExactAlarmPlatform _exactAlarm;
  final void Function()? onPrefsChanged;
  final double moveThresholdMeters;

  Future<void> syncNativeFlag(PrayerPrefs prefs) {
    return _exactAlarm.syncTravelLocation(
      enabled: prefs.travelScheduleUpdates,
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );
  }

  Future<void> syncFromStore() async {
    await syncNativeFlag(await _store.read());
  }

  /// Returns true when city/coords were rewritten.
  Future<bool> refreshIfMoved() async {
    final prefs = await _store.read();
    await syncNativeFlag(prefs);
    if (!prefs.travelScheduleUpdates || !prefs.configured) return false;
    if (!await _location.hasGrantedPermission()) return false;

    late final ResolvedLocation resolved;
    try {
      resolved = await _location.resolveCurrent();
    } catch (_) {
      return false;
    }

    if (prefs.hasCoordinates) {
      final distance = Geolocator.distanceBetween(
        prefs.latitude!,
        prefs.longitude!,
        resolved.latitude,
        resolved.longitude,
      );
      final sameCity = prefs.city == resolved.city &&
          prefs.country == resolved.country;
      if (distance < moveThresholdMeters && sameCity) return false;
    }

    await _store.write(
      prefs.copyWith(
        city: resolved.city,
        country: resolved.country,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
        administrativeArea: resolved.administrativeArea,
      ),
    );
    await syncNativeFlag(await _store.read());
    onPrefsChanged?.call();
    return true;
  }
}
