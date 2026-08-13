package com.tursinalabs.prayer_cast

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExactAlarmPlugin.registerWith(flutterEngine, applicationContext)
        OemBatteryPlugin.registerWith(flutterEngine, applicationContext)
        DeviceConditionsPlugin.registerWith(flutterEngine, applicationContext)
        NetworkPrefixPlugin.registerWith(flutterEngine)
        CastReadyPlugin.registerWith(flutterEngine, applicationContext)
    }
}
