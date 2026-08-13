/// Curated cities for offline prayer-time calculation (no GPS).
final class PrayerCity {
  const PrayerCity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
}

/// Built-in city list. Coordinates are city-center approximations.
abstract final class PrayerCities {
  static const List<PrayerCity> all = [
    PrayerCity(
      id: 'singapore',
      name: 'Singapore',
      latitude: 1.3521,
      longitude: 103.8198,
    ),
    PrayerCity(
      id: 'jakarta',
      name: 'Jakarta',
      latitude: -6.2088,
      longitude: 106.8456,
    ),
    PrayerCity(
      id: 'bandung',
      name: 'Bandung',
      latitude: -6.9175,
      longitude: 107.6191,
    ),
    PrayerCity(
      id: 'surabaya',
      name: 'Surabaya',
      latitude: -7.2575,
      longitude: 112.7521,
    ),
    PrayerCity(
      id: 'yogyakarta',
      name: 'Yogyakarta',
      latitude: -7.7956,
      longitude: 110.3695,
    ),
    PrayerCity(
      id: 'medan',
      name: 'Medan',
      latitude: 3.5952,
      longitude: 98.6722,
    ),
    PrayerCity(
      id: 'makassar',
      name: 'Makassar',
      latitude: -5.1477,
      longitude: 119.4327,
    ),
    PrayerCity(
      id: 'semarang',
      name: 'Semarang',
      latitude: -6.9667,
      longitude: 110.4167,
    ),
    PrayerCity(
      id: 'palembang',
      name: 'Palembang',
      latitude: -2.9761,
      longitude: 104.7754,
    ),
    PrayerCity(
      id: 'denpasar',
      name: 'Denpasar',
      latitude: -8.6705,
      longitude: 115.2126,
    ),
    PrayerCity(
      id: 'balikpapan',
      name: 'Balikpapan',
      latitude: -1.2379,
      longitude: 116.8529,
    ),
    PrayerCity(
      id: 'pontianak',
      name: 'Pontianak',
      latitude: -0.0263,
      longitude: 109.3425,
    ),
    PrayerCity(
      id: 'manado',
      name: 'Manado',
      latitude: 1.4748,
      longitude: 124.8421,
    ),
  ];

  static PrayerCity? byId(String id) {
    for (final city in all) {
      if (city.id == id) return city;
    }
    return null;
  }

  static const PrayerCity defaultCity = PrayerCity(
    id: 'singapore',
    name: 'Singapore',
    latitude: 1.3521,
    longitude: 103.8198,
  );
}
