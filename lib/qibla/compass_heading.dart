import 'package:flutter_device_compass/flutter_device_compass.dart';

/// Whether the platform can deliver a live heading at all.
enum CompassAvailability {
  /// Still probing the sensors. The page shows a short placeholder, never a
  /// dead dial.
  probing,

  /// Sensors answered. [CompassReading.headingDeg] can still be null for the
  /// first few samples while they settle.
  live,

  /// No magnetometer / rotation vector, or the plugin refused to start.
  unavailable,
}

/// One compass sample: heading plus the platform accuracy estimate.
final class CompassReading {
  const CompassReading.probing()
    : availability = CompassAvailability.probing,
      headingDeg = null,
      accuracyDeg = null;

  const CompassReading.unavailable()
    : availability = CompassAvailability.unavailable,
      headingDeg = null,
      accuracyDeg = null;

  const CompassReading.live({this.headingDeg, this.accuracyDeg})
    : availability = CompassAvailability.live;

  final CompassAvailability availability;

  /// Degrees, 0 = north, clockwise. Null until the sensors settle.
  final double? headingDeg;

  /// Plus/minus deviation reported by the platform, in degrees. Null when the
  /// platform reports nothing usable; then no calibration hint is shown.
  final double? accuracyDeg;

  /// Android maps the sensor status to 15 (high) / 30 (medium) / 45 (low);
  /// iOS reports a measured deviation. Anything above this is coarse enough
  /// to be worth a hint.
  static const double coarseAccuracyDeg = 25;

  bool get hasHeading => headingDeg != null;

  /// Platform says the reading is coarse. The needle is never hidden for
  /// this; the page shows a dismissible calibration hint instead.
  bool get needsCalibration {
    final deviation = accuracyDeg;
    return deviation != null && deviation > coarseAccuracyDeg;
  }
}

/// Device heading in degrees, 0 = north, clockwise, plus availability.
abstract interface class CompassHeadingSource {
  Stream<CompassReading> readings();
}

/// Magnetometer / rotation-vector heading. No fine location.
final class DeviceCompassHeadingSource implements CompassHeadingSource {
  const DeviceCompassHeadingSource();

  @override
  Stream<CompassReading> readings() async* {
    yield const CompassReading.probing();
    bool supported;
    try {
      // Probe the MethodChannel first. After a hot restart the plugin is
      // often missing; listening on the EventChannel would dump
      // MissingPluginException via the services library.
      supported = await FlutterCompass.hasSensors == true;
    } catch (_) {
      supported = false;
    }
    if (!supported) {
      yield const CompassReading.unavailable();
      return;
    }
    Stream<CompassEvent>? events;
    try {
      events = FlutterCompass.eventsFor(CompassUpdateOptions.balanced);
    } catch (_) {
      events = null;
    }
    if (events == null) {
      yield const CompassReading.unavailable();
      return;
    }
    yield* events
        .map(
          (event) => CompassReading.live(
            headingDeg: event.heading,
            accuracyDeg: event.accuracy,
          ),
        )
        .handleError((_, __) {});
  }
}

/// Injected in tests so the kiblat page does not need a magnetometer.
final class StreamCompassHeadingSource implements CompassHeadingSource {
  const StreamCompassHeadingSource(this._stream);

  /// Heading-only stream for tests and demo builds; accuracy stays unknown,
  /// so no calibration hint appears.
  factory StreamCompassHeadingSource.headings(Stream<double?> headings) {
    return StreamCompassHeadingSource(
      headings.map((heading) => CompassReading.live(headingDeg: heading)),
    );
  }

  final Stream<CompassReading> _stream;

  @override
  Stream<CompassReading> readings() => _stream;
}
