import 'package:flutter_device_compass/flutter_device_compass.dart';

/// Device heading in degrees, 0 = north, clockwise. Null when unavailable.
abstract interface class CompassHeadingSource {
  Stream<double?> headings();
}

/// Magnetometer / rotation-vector heading. No fine location.
final class DeviceCompassHeadingSource implements CompassHeadingSource {
  const DeviceCompassHeadingSource();

  @override
  Stream<double?> headings() async* {
    yield null;
    try {
      // Probe the MethodChannel first. After a hot restart the plugin is
      // often missing; listening on the EventChannel would dump
      // MissingPluginException via the services library.
      final supported = await FlutterCompass.hasSensors;
      if (supported != true) return;
    } catch (_) {
      return;
    }
    try {
      final events = FlutterCompass.eventsFor(CompassUpdateOptions.balanced);
      if (events == null) return;
      yield* events.map((event) => event.heading).handleError((_, __) {});
    } catch (_) {}
  }
}

/// Injected in tests so the kiblat page does not need a magnetometer.
final class StreamCompassHeadingSource implements CompassHeadingSource {
  const StreamCompassHeadingSource(this._stream);

  final Stream<double?> _stream;

  @override
  Stream<double?> headings() => _stream;
}
