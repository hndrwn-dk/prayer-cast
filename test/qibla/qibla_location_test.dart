import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/cities.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/qibla/qibla_location.dart';

void main() {
  test('GPS coordinates win over the city catalogue', () {
    final fix = resolveQiblaLocation(
      PrayerPrefs.defaults.copyWith(
        city: 'Singapore',
        country: 'Singapore',
        latitude: -6.2,
        longitude: 106.8,
      ),
    );
    expect(fix, isNotNull);
    expect(fix!.latitude, closeTo(-6.2, 0.0001));
    expect(fix.longitude, closeTo(106.8, 0.0001));
    expect(fix.source, QiblaLocationSource.coordinates);
  });

  test('catalogue match covers typed Jakarta without GPS', () {
    final fix = resolveQiblaLocation(
      PrayerPrefs.defaults.copyWith(
        city: 'KOTA JAKARTA PUSAT',
        country: 'Indonesia',
      ),
    );
    expect(fix, isNotNull);
    expect(fix!.source, QiblaLocationSource.cityCatalog);
    expect(fix.latitude, PrayerCities.match('Jakarta')!.latitude);
  });

  test('unknown city without coordinates cannot resolve', () {
    final fix = resolveQiblaLocation(
      PrayerPrefs.defaults.copyWith(city: 'Atlantis', country: 'Ocean'),
    );
    expect(fix, isNull);
  });

  test('Singapore defaults resolve from the catalogue', () {
    final fix = resolveQiblaLocation(PrayerPrefs.defaults);
    expect(fix, isNotNull);
    expect(fix!.source, QiblaLocationSource.cityCatalog);
    expect(fix.latitude, PrayerCities.defaultCity.latitude);
  });
}
