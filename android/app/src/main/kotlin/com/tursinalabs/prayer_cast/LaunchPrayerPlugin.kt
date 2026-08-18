package com.tursinalabs.prayer_cast

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Surfaces the notification-tap `prayer` extra to Dart so
 * [SpiritualBenefitsPage] can open after first frame. Does not start
 * or delay delivery. The T−120 FGS does not launch the activity.
 */
object LaunchPrayerPlugin {
    const val CHANNEL = "prayer_cast/launch"

    private var channel: MethodChannel? = null
    private var activity: MainActivity? = null

    fun bind(engine: FlutterEngine, host: MainActivity) {
        activity = host
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { method ->
            method.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunchPrayer" -> result.success(consume(host))
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun notifyNewIntent(intent: Intent) {
        val prayer = intent.getStringExtra(ExactAlarmPlugin.EXTRA_PRAYER) ?: return
        intent.removeExtra(ExactAlarmPlugin.EXTRA_PRAYER)
        channel?.invokeMethod("onLaunchPrayer", prayer)
    }

    private fun consume(host: MainActivity): String? {
        val prayer = host.intent?.getStringExtra(ExactAlarmPlugin.EXTRA_PRAYER)
        host.intent?.removeExtra(ExactAlarmPlugin.EXTRA_PRAYER)
        return prayer
    }
}
