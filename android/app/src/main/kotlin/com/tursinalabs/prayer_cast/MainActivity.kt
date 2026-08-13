package com.tursinalabs.prayer_cast

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExactAlarmPlugin.registerWith(flutterEngine, applicationContext)
        OemBatteryPlugin.registerWith(flutterEngine, applicationContext)
        DeviceConditionsPlugin.registerWith(flutterEngine, applicationContext)
        NetworkPrefixPlugin.registerWith(flutterEngine)
    }
}
