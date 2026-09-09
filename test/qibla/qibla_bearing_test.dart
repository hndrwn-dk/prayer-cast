import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/cities.dart';
import 'package:prayer_cast/qibla/qibla_bearing.dart';

void main() {
  test('Jakarta qibla is west-northwest, around 295 degrees', () {
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
    expect(cardinalLabel(bearing, isId: false), 'WNW');
    expect(cardinalLabel(bearing, isId: true), 'BBL');
  });

  test('cardinal label uses the sixteen-point rose, not eight', () {
    expect(cardinalLabel(293, isId: false), 'WNW');
    expect(cardinalLabel(293, isId: true), 'BBL');
    expect(cardinalLabel(315, isId: false), 'NW');
    expect(cardinalLabel(337.5, isId: false), 'NNW');
    expect(cardinalLabel(22.5, isId: false), 'NNE');
    expect(cardinalLabel(112.5, isId: false), 'ESE');
    expect(cardinalLabel(112.5, isId: true), 'TM');
  });

  test('cardinal label matches the sector centre across 0-360', () {
    const centres = <(double, String)>[
      (0, 'N'),
      (22.5, 'NNE'),
      (45, 'NE'),
      (67.5, 'ENE'),
      (90, 'E'),
      (112.5, 'ESE'),
      (135, 'SE'),
      (157.5, 'SSE'),
      (180, 'S'),
      (202.5, 'SSW'),
      (225, 'SW'),
      (247.5, 'WSW'),
      (270, 'W'),
      (292.5, 'WNW'),
      (315, 'NW'),
      (337.5, 'NNW'),
    ];
    for (final (centre, label) in centres) {
      // Whole sector, from just after the previous boundary to just before
      // the next one.
      for (var offset = -11.0; offset <= 11.0; offset += 1) {
        final degrees = centre + offset;
        expect(
          cardinalLabel(degrees, isId: false),
          label,
          reason: 'bearing $degrees should read $label',
        );
      }
    }
  });

  test('cardinal label wraps negative and over-spin bearings', () {
    expect(cardinalLabel(360, isId: false), 'N');
    expect(cardinalLabel(-90, isId: false), 'W');
    expect(cardinalLabel(-22.5, isId: false), 'NNW');
    expect(cardinalLabel(725, isId: false), 'N');
  });

  test('sixteen-point labels stay unique in both languages', () {
    final en = <String>{};
    final id = <String>{};
    for (var i = 0; i < 16; i++) {
      en.add(cardinalLabel(i * 22.5, isId: false));
      id.add(cardinalLabel(i * 22.5, isId: true));
    }
    expect(en, hasLength(16));
    expect(id, hasLength(16));
  });

  test('signed heading delta picks the short turn and alignment band', () {
    expect(signedHeadingDelta(0, 10), closeTo(10, 0.001));
    expect(signedHeadingDelta(10, 0), closeTo(-10, 0.001));
    expect(signedHeadingDelta(350, 10), closeTo(20, 0.001));
    expect(signedHeadingDelta(10, 350), closeTo(-20, 0.001));
    expect(qiblaAligned(292, 295), isTrue);
    expect(qiblaAligned(280, 295), isFalse);
  });

  test('alignment latch reports the lock-on edge only once', () {
    final latch = QiblaAlignmentLatch();
    expect(latch.update(280, 295), isFalse);
    expect(latch.aligned, isFalse);
    expect(latch.update(293, 295), isTrue);
    expect(latch.aligned, isTrue);
    expect(latch.update(295, 295), isFalse);
    expect(latch.update(297, 295), isFalse);
    expect(latch.aligned, isTrue);
  });

  test('alignment latch holds through edge jitter, then releases', () {
    final latch = QiblaAlignmentLatch();
    latch.update(295, 295);
    expect(latch.aligned, isTrue);
    // Outside the 5 degree entry band but inside the 8 degree exit band.
    expect(latch.update(302, 295), isFalse);
    expect(latch.aligned, isTrue);
    expect(latch.update(288, 295), isFalse);
    expect(latch.aligned, isTrue);
    // Past the exit band.
    expect(latch.update(280, 295), isFalse);
    expect(latch.aligned, isFalse);
    // Re-entry needs the tighter band and fires the edge again.
    expect(latch.update(302, 295), isFalse);
    expect(latch.update(296, 295), isTrue);
  });

  test('alignment latch wraps across north and drops a null heading', () {
    final latch = QiblaAlignmentLatch();
    expect(latch.update(358, 2), isTrue);
    expect(latch.update(null, 2), isFalse);
    expect(latch.aligned, isFalse);
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
