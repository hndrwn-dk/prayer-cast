import Flutter
import UIKit

/// Live device conditions for election priority (spec §4.4).
///
/// Channel: prayer_cast/device_conditions
public class DeviceConditionsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "prayer_cast/device_conditions",
      binaryMessenger: registrar.messenger()
    )
    let instance = DeviceConditionsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "current":
      result(current())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func current() -> [String: Any] {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true

    let level = device.batteryLevel
    let percent: Int
    if level < 0 {
      percent = 50
    } else {
      percent = Int((level * 100).rounded())
    }

    let state = device.batteryState
    let isPluggedIn = state == .charging || state == .full

    // iOS has no clean isScreenOn for a backgrounded app — return true as a
    // known approximation (tablet priority "screen on" row is best-effort).
    let isScreenOn = true

    let formFactor = device.userInterfaceIdiom == .pad ? "tablet" : "phone"

    // ProcessInfo lowPowerMode is the closest battery-saver signal on iOS.
    let batterySaverActive = ProcessInfo.processInfo.isLowPowerModeEnabled

    return [
      "formFactor": formFactor,
      "isPluggedIn": isPluggedIn,
      "isScreenOn": isScreenOn,
      "batteryPercent": max(0, min(100, percent)),
      "batterySaverActive": batterySaverActive,
    ]
  }
}
