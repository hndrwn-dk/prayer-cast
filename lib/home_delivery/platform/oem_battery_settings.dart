import 'package:flutter/services.dart';

import '../common/logger.dart';

/// Opens the OEM battery-optimisation settings page (spec §6.3).
///
/// WHY: Xiaomi, Oppo, Vivo, and Samsung hide unrestricted-background toggles
/// behind manufacturer screens. Generic Android settings are the fallback.
abstract interface class OemBatterySettingsPlatform {
  /// True when the platform can open a battery-related settings screen.
  Future<bool> canOpen();

  /// Opens the best available OEM / system battery settings page.
  Future<bool> open();
}

/// MethodChannel bridge to Android OEM battery intents.
final class OemBatterySettings implements OemBatterySettingsPlatform {
  OemBatterySettings({
    MethodChannel? methodChannel,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _methods = methodChannel ??
            const MethodChannel('prayer_cast/oem_battery'),
        _logger = logger;

  final MethodChannel _methods;
  final HomeDeliveryLogger _logger;

  @override
  Future<bool> canOpen() async {
    try {
      final value = await _methods.invokeMethod<bool>('canOpen');
      return value ?? false;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'OemBatterySettings.canOpen failed',
        tag: 'OemBattery',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  @override
  Future<bool> open() async {
    try {
      final value = await _methods.invokeMethod<bool>('open');
      return value ?? false;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'OemBatterySettings.open failed',
        tag: 'OemBattery',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}

/// Pure helper: show the OEM nudge after 2× [FAILED_ALARM_MISSED] in 7 days.
bool shouldShowOemBatteryNudge(int failedAlarmMissedCount) =>
    failedAlarmMissedCount >= 2;
