import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart';

/// True-north bearing to the Kaaba, 0–360 clockwise from north.
double qiblaBearingDegrees({
  required double latitude,
  required double longitude,
}) {
  return Qibla.qibla(Coordinates(latitude, longitude));
}

/// Shortest signed turn from [fromDeg] to [toDeg], in (−180, 180].
double signedHeadingDelta(double fromDeg, double toDeg) {
  var d = (toDeg - fromDeg) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

bool qiblaAligned(
  double headingDeg,
  double qiblaDeg, {
  double toleranceDeg = 5,
}) {
  return signedHeadingDelta(headingDeg, qiblaDeg).abs() <= toleranceDeg;
}

/// Alignment gate with hysteresis.
///
/// Locks on inside [enterToleranceDeg] and only lets go past
/// [exitToleranceDeg], so a heading jittering on the tolerance edge cannot
/// flicker the needle colour or retrigger the haptic.
final class QiblaAlignmentLatch {
  QiblaAlignmentLatch({this.enterToleranceDeg = 5, this.exitToleranceDeg = 8});

  final double enterToleranceDeg;
  final double exitToleranceDeg;

  bool _aligned = false;

  bool get aligned => _aligned;

  /// Feeds one heading. Returns true only on the transition into alignment,
  /// so the caller fires exactly one haptic per lock-on.
  bool update(double? headingDeg, double qiblaDeg) {
    if (headingDeg == null) {
      _aligned = false;
      return false;
    }
    final off = signedHeadingDelta(headingDeg, qiblaDeg).abs();
    final wasAligned = _aligned;
    _aligned = wasAligned ? off <= exitToleranceDeg : off <= enterToleranceDeg;
    return _aligned && !wasAligned;
  }
}

/// Great-circle distance in metres (WGS84 mean radius).
double haversineMeters({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  const radius = 6371000.0;
  final p1 = fromLat * math.pi / 180;
  final p2 = toLat * math.pi / 180;
  final dp = (toLat - fromLat) * math.pi / 180;
  final dl = (toLng - fromLng) * math.pi / 180;
  final a =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Initial great-circle bearing, 0–360 clockwise from true north.
double initialBearingDegrees({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final p1 = fromLat * math.pi / 180;
  final p2 = toLat * math.pi / 180;
  final dl = (toLng - fromLng) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x =
      math.cos(p1) * math.sin(p2) -
      math.sin(p1) * math.cos(p2) * math.cos(dl);
  final degrees = math.atan2(y, x) * 180 / math.pi;
  return (degrees + 360) % 360;
}

/// Sixteen-wind cardinal for a bearing, so 293 reads WNW and not NW.
///
/// [isId] uses the Indonesian abbreviations (U, UTL, TL, TTL, ...).
String cardinalLabel(double degrees, {required bool isId}) {
  const en = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  const id = [
    'U',
    'UTL',
    'TL',
    'TTL',
    'T',
    'TM',
    'TG',
    'SM',
    'S',
    'SBD',
    'BD',
    'BBD',
    'B',
    'BBL',
    'BL',
    'UBL',
  ];
  var d = degrees % 360;
  if (d < 0) d += 360;
  final i = ((d + 11.25) / 22.5).floor() % 16;
  return isId ? id[i] : en[i];
}

String formatDistanceMeters(double meters, {required bool isId}) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final km = meters / 1000;
  final label = km >= 10 ? km.round().toString() : km.toStringAsFixed(1);
  return isId ? '$label km' : '$label km';
}
