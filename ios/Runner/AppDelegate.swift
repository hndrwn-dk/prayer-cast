import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "AudioKeepalivePlugin") {
      AudioKeepalivePlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "DeviceConditionsPlugin") {
      DeviceConditionsPlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "NetworkPrefixPlugin") {
      NetworkPrefixPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
