import Flutter
import UIKit

/// Dhikr counter helpers (lib/dhikr/platform/dhikr_device.dart).
///
/// Channel: prayer_cast/dhikr
/// iOS gives apps no supported way to read the volume buttons, so
/// setVolumeKeyCounting reports false and Dart hides that hint.
public class DhikrDevicePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "prayer_cast/dhikr",
      binaryMessenger: registrar.messenger()
    )
    let instance = DhikrDevicePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setKeepScreenOn":
      let on = (call.arguments as? Bool) ?? false
      DispatchQueue.main.async {
        UIApplication.shared.isIdleTimerDisabled = on
        result(true)
      }
    case "setVolumeKeyCounting":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
