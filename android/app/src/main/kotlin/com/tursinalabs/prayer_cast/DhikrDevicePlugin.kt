package com.tursinalabs.prayer_cast

import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Dhikr counter helpers (lib/dhikr/platform/dhikr_device.dart):
 * keep the screen on while counting, and turn the volume buttons into a
 * tap counter so the phone can stay in a pocket.
 */
object DhikrDevicePlugin {
    const val CHANNEL = "prayer_cast/dhikr"

    private var channel: MethodChannel? = null
    private var host = WeakReference<MainActivity>(null)

    @Volatile
    private var countVolumeKeys = false

    fun bind(engine: FlutterEngine, activity: MainActivity) {
        host = WeakReference(activity)
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            val on = call.arguments as? Boolean ?: false
            when (call.method) {
                "setKeepScreenOn" -> {
                    val window = host.get()?.window
                    if (window == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "setVolumeKeyCounting" -> {
                    countVolumeKeys = on
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** Called from [MainActivity.dispatchKeyEvent]; true = consumed. */
    fun handleKey(event: KeyEvent): Boolean {
        if (!countVolumeKeys) return false
        val code = event.keyCode
        if (code != KeyEvent.KEYCODE_VOLUME_UP && code != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return false
        }
        // Consume both down and up so the system volume panel never shows;
        // count only the first down, so holding the button is one tap.
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            channel?.invokeMethod("volumeKey", null)
        }
        return true
    }

    /** The activity lost focus (or is gone): stop stealing volume keys. */
    fun release() {
        countVolumeKeys = false
    }
}
