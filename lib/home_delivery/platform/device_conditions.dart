import 'package:flutter/services.dart';

import '../common/logger.dart';
import '../coordination/device_identity.dart';

/// Live device conditions for election priority (§4.4).
abstract interface class DeviceConditionsProvider {
  Future<DeviceConditions> current();
}

/// MethodChannel bridge — `prayer_cast/device_conditions`.
///
/// WHY: Matches ExactAlarm's channel pattern. No pub.dev battery/device
/// packages — native code owns BatteryManager / UIDevice.
///
/// - [DeviceConditions.isHub] is hardcoded `false` (TODO: hub build flavour,
///   spec §9).
/// - [DeviceConditions.clockSkewDetected] is always `false` here. Election
///   re-derives effective priority from CLAIM timestamps in `_decideRole`
///   regardless of this base value — do not invent advance skew prediction.
final class MethodChannelDeviceConditions implements DeviceConditionsProvider {
  MethodChannelDeviceConditions({
    MethodChannel? methodChannel,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _methods = methodChannel ??
            const MethodChannel('prayer_cast/device_conditions'),
        _logger = logger;

  final MethodChannel _methods;
  final HomeDeliveryLogger _logger;

  @override
  Future<DeviceConditions> current() async {
    try {
      final raw = await _methods.invokeMethod<Map<Object?, Object?>>('current');
      if (raw == null) {
        return _fallback();
      }
      final map = <String, Object?>{
        for (final e in raw.entries) e.key.toString(): e.value,
      };
      return DeviceConditions(
        formFactor: _parseFormFactor(map['formFactor']),
        isPluggedIn: map['isPluggedIn'] == true,
        isScreenOn: map['isScreenOn'] == true,
        batteryPercent: (map['batteryPercent'] as num?)?.toInt().clamp(0, 100) ?? 50,
        batterySaverActive: map['batterySaverActive'] == true,
        // Always false — Election detects skew from CLAIM timestamps live.
        clockSkewDetected: false,
        // TODO(spec §9): hub build flavour / separate listing.
        isHub: false,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'DeviceConditions.current failed — using conservative fallback',
        tag: 'DeviceConditions',
        error: e,
        stackTrace: st,
      );
      return _fallback();
    }
  }

  static DeviceFormFactor _parseFormFactor(Object? raw) {
    if (raw == 'tablet') return DeviceFormFactor.tablet;
    return DeviceFormFactor.phone;
  }

  static DeviceConditions _fallback() => const DeviceConditions(
        formFactor: DeviceFormFactor.phone,
        isPluggedIn: false,
        isScreenOn: true,
        batteryPercent: 50,
        batterySaverActive: false,
        clockSkewDetected: false,
        isHub: false,
      );
}
