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

/// Eight-wind cardinal for a bearing. [isId] uses U/TL/T/TG/S/BD/B/BL.
String cardinalLabel(double degrees, {required bool isId}) {
  const en = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const id = ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
  var d = degrees % 360;
  if (d < 0) d += 360;
  final i = ((d + 22.5) / 45).floor() % 8;
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
