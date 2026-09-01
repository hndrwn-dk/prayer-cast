import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/cities.dart';
import 'package:prayer_cast/qibla/qibla_bearing.dart';

void main() {
  test('Jakarta qibla is northwest of north, around 295 degrees', () {
    const jakarta = PrayerCity(
      id: 'jakarta',
      name: 'Jakarta',
      latitude: -6.2088,
      longitude: 106.8456,
    );
    final bearing = qiblaBearingDegrees(
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
    );
    expect(bearing, inInclusiveRange(285, 305));
    expect(cardinalLabel(bearing, isId: false), 'NW');
    expect(cardinalLabel(bearing, isId: true), 'BL');
  });

  test('signed heading delta picks the short turn and alignment band', () {
    expect(signedHeadingDelta(0, 10), closeTo(10, 0.001));
    expect(signedHeadingDelta(10, 0), closeTo(-10, 0.001));
    expect(signedHeadingDelta(350, 10), closeTo(20, 0.001));
    expect(signedHeadingDelta(10, 350), closeTo(-20, 0.001));
    expect(qiblaAligned(292, 295), isTrue);
    expect(qiblaAligned(280, 295), isFalse);
  });

  test('haversine is zero at the same point and positive otherwise', () {
    expect(
      haversineMeters(
        fromLat: -6.2088,
        fromLng: 106.8456,
        toLat: -6.2088,
        toLng: 106.8456,
      ),
      closeTo(0, 0.01),
    );
    final metres = haversineMeters(
      fromLat: -6.2088,
      fromLng: 106.8456,
      toLat: -6.1754,
      toLng: 106.8272,
    );
    expect(metres, greaterThan(3000));
    expect(metres, lessThan(5000));
  });
}
