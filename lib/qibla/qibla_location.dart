import '../prayer_times/cities.dart';
import '../prayer_times/prayer_prefs.dart';

enum QiblaLocationSource { coordinates, cityCatalog, mapPin }

/// On-device fix used for kiblat and the mosque map. Never sent until Overpass.
final class QiblaFix {
  const QiblaFix({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final String label;
  final QiblaLocationSource source;
}

/// Prefs GPS first, then a curated city match. Null if neither is available.
QiblaFix? resolveQiblaLocation(PrayerPrefs prefs) {
  if (prefs.hasCoordinates) {
    return QiblaFix(
      latitude: prefs.latitude!,
      longitude: prefs.longitude!,
      label: prefs.displayLocation,
      source: QiblaLocationSource.coordinates,
    );
  }
  final city = PrayerCities.match(prefs.city);
  if (city == null) return null;
  return QiblaFix(
    latitude: city.latitude,
    longitude: city.longitude,
    label: prefs.city.trim().isEmpty ? city.name : prefs.displayLocation,
    source: QiblaLocationSource.cityCatalog,
  );
}
