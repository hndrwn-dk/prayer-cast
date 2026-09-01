import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';

void main() {
  test('prayer-city GPS uses balanced approximate settings, not fine GPS', () {
    expect(LocationResolver.coarseSettings, isA<AndroidSettings>());
    expect(LocationResolver.coarseSettings.accuracy, LocationAccuracy.medium);
    expect(LocationResolver.coarseSettings.timeLimit, isNull);
    expect(
      LocationResolver.coarseSettings.accuracy,
      isNot(LocationAccuracy.high),
    );
    expect(
      LocationResolver.coarseSettings.accuracy,
      isNot(LocationAccuracy.best),
    );
    final android = LocationResolver.coarseSettings as AndroidSettings;
    expect(android.intervalDuration, Duration.zero);
    expect(android.forceLocationManager, isFalse);
  });

  test('nearby mosques GPS uses high accuracy', () {
    expect(LocationResolver.preciseSettings.accuracy, LocationAccuracy.high);
  });

  test('last known with finite coords is usable for approximate location', () {
    final now = DateTime.utc(2026, 8, 16, 10);
    expect(
      LocationResolver.hasUsableCoordinates(
        _position(timestamp: now.subtract(const Duration(hours: 2))),
      ),
      isTrue,
    );
    expect(LocationResolver.hasUsableCoordinates(null), isFalse);
  });

  test('Indonesia prefers kabupaten as city and as admin hint', () {
    final labels = LocationResolver.labelsFromGeocode(
      country: 'Indonesia',
      locality: 'Menteng',
      subAdministrativeArea: 'Jakarta Pusat',
      administrativeArea: 'DKI Jakarta',
    );
    expect(labels.city, 'Jakarta Pusat');
    expect(labels.country, 'Indonesia');
    expect(labels.administrativeArea, 'Jakarta Pusat');
  });

  test('kelurahan-only locality keeps kabupaten from admin area', () {
    final jakarta = LocationResolver.labelsFromGeocode(
      country: 'Indonesia',
      locality: 'Menteng',
      subAdministrativeArea: '',
      administrativeArea: 'Jakarta Pusat',
    );
    expect(jakarta.city, 'Menteng');
    expect(jakarta.administrativeArea, 'Jakarta Pusat');

    final sleman = LocationResolver.labelsFromGeocode(
      country: 'ID',
      locality: 'Condongcatur',
      subAdministrativeArea: '',
      administrativeArea: 'Kabupaten Sleman',
    );
    expect(sleman.city, 'Condongcatur');
    expect(sleman.administrativeArea, 'Kabupaten Sleman');
  });
}

Position _position({required DateTime timestamp}) {
  return Position(
    longitude: 106.8,
    latitude: -6.2,
    timestamp: timestamp,
    accuracy: 500,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
