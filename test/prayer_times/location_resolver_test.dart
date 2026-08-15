import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';

void main() {
  test('prayer-city GPS uses coarse accuracy, not fine', () {
    expect(LocationResolver.coarseSettings.accuracy, LocationAccuracy.low);
    expect(
      LocationResolver.coarseSettings.accuracy,
      isNot(LocationAccuracy.high),
    );
    expect(
      LocationResolver.coarseSettings.accuracy,
      isNot(LocationAccuracy.best),
    );
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
