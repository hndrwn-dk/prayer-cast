package com.tursinalabs.prayer_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Probe for Cast RemoteMediaClient and session connect. Native
 * startSessionWithDeviceId returns true on route select; the session may
 * still be stuck in CastSession.<init> / GMS Dynamite load (group speakers).
 * RemoteMediaClient.load is a silent no-op until the media client exists.
 */
class CastReadyPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isMediaClientReady" -> result.success(isMediaClientReady())
            "isSessionConnected" -> result.success(isSessionConnected())
            "ensureCastContext" -> ensureCastContext(result)
            else -> result.notImplemented()
        }
    }

    private fun ensureCastContext(result: MethodChannel.Result) {
        // getSharedInstance can block on Dynamite module load — keep it off
        // the platform thread. Calling this at T-120 warms GMS before prepare.
        executor.execute {
            val ok = try {
                CastContext.getSharedInstance(context) != null
            } catch (e: Exception) {
                Log.w(TAG, "ensureCastContext failed", e)
                false
            }
            mainHandler.post { result.success(ok) }
        }
    }

    private fun isSessionConnected(): Boolean {
        return try {
            CastContext.getSharedInstance(context)
                ?.sessionManager
                ?.currentCastSession
                ?.isConnected == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isMediaClientReady(): Boolean {
        return try {
            CastContext.getSharedInstance(context)
                ?.sessionManager
                ?.currentCastSession
                ?.remoteMediaClient != null
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val TAG = "CastReadyPlugin"
        const val CHANNEL = "prayer_cast/cast_ready"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).setMethodCallHandler(
                CastReadyPlugin(context.applicationContext),
            )
        }
    }
}
