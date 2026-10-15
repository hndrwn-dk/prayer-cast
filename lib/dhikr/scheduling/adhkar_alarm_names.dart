import 'package:prayer_cast/dhikr/models/adhkar_type.dart';

/// Alarm and delivery-log markers for scheduled adhkar.
///
/// Prefixed so they never collide with a real prayer name (`fajr`, `asr`).
abstract final class AdhkarAlarmNames {
  static const morning = 'adhkar-morning';
  static const evening = 'adhkar-evening';

  static String of(AdhkarType type) => switch (type) {
    AdhkarType.morning => morning,
    AdhkarType.evening => evening,
  };

  static AdhkarType? parse(String prayer) => switch (prayer) {
    morning => AdhkarType.morning,
    evening => AdhkarType.evening,
    _ => null,
  };
}
