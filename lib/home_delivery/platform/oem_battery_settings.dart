import 'package:flutter/services.dart';

import '../common/logger.dart';

/// Opens OEM battery-optimisation and autostart settings (spec §6.3).
///
/// WHY: Xiaomi, Oppo, Vivo, and Samsung hide unrestricted-background
/// toggles behind manufacturer screens. ColorOS / MIUI / Funtouch also
/// hide Auto-launch, a separate gate that can drop BOOT_COMPLETED.
/// Generic Android settings are the fallback.
abstract interface class OemBatterySettingsPlatform {
  /// True when the platform can open a battery-related settings screen.
  Future<bool> canOpen();

  /// Opens the best available OEM / system battery settings page.
  Future<bool> open();

  /// Opens Auto-launch / Startup Manager. Not the battery screen.
  Future<bool> openAutostartSettings();

  /// ColorOS / MIUI / Funtouch-class OEM that hides Auto-launch.
  Future<bool> isRestrictiveOem();
}

/// MethodChannel bridge to Android OEM battery and autostart intents.
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
    } on MissingPluginException {
      return false;
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
    } on MissingPluginException {
      return false;
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

  @override
  Future<bool> openAutostartSettings() async {
    try {
      final value = await _methods.invokeMethod<bool>('openAutostartSettings');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'OemBatterySettings.openAutostartSettings failed',
        tag: 'OemBattery',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  @override
  Future<bool> isRestrictiveOem() async {
    try {
      final value = await _methods.invokeMethod<bool>('isRestrictiveOem');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'OemBatterySettings.isRestrictiveOem failed',
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
