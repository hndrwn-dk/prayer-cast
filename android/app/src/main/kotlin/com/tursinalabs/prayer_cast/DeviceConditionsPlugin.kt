package com.tursinalabs.prayer_cast

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Live device conditions for election priority (spec §4.4).
 *
 * Channel: prayer_cast/device_conditions
 */
class DeviceConditionsPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> result.success(current())
            else -> result.notImplemented()
        }
    }

    private fun current(): Map<String, Any> {
        val battery = context.getSystemService(BatteryManager::class.java)
        val percent = battery?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?: readPercentFromSticky()

        val intent = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isPluggedIn = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL ||
            (intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0

        val pm = context.getSystemService(PowerManager::class.java)
        val batterySaverActive = pm?.isPowerSaveMode == true
        val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            pm?.isInteractive == true
        } else {
            @Suppress("DEPRECATION")
            pm?.isScreenOn == true
        }

        val sw = context.resources.configuration.smallestScreenWidthDp
        val formFactor = if (sw >= 600) "tablet" else "phone"

        return mapOf(
            "formFactor" to formFactor,
            "isPluggedIn" to isPluggedIn,
            "isScreenOn" to isScreenOn,
            "batteryPercent" to percent.coerceIn(0, 100),
            "batterySaverActive" to batterySaverActive,
        )
    }

    private fun readPercentFromSticky(): Int {
        val intent = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        ) ?: return 50
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, 50)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1)
        return ((level * 100f) / scale).toInt().coerceIn(0, 100)
    }

    companion object {
        const val CHANNEL = "prayer_cast/device_conditions"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).setMethodCallHandler(DeviceConditionsPlugin(context.applicationContext))
        }
    }
}
