package com.tursinalabs.prayer_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.mediarouter.media.MediaRouter
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
            "hasCastSession" -> result.success(hasCastSession())
            "ensureCastContext" -> ensureCastContext(result)
            else -> result.notImplemented()
        }
    }

    private fun ensureCastContext(result: MethodChannel.Result) {
        // SDK 21.5 checks the main thread on both getSharedInstance overloads
        // before it loads the Cast module. A worker thread throws
        // IllegalStateException and the warm-up never creates a context
        // (Maghrib 2026-10-16: speaker never started).
        mainHandler.post {
            try {
                CastContext.getSharedInstance(context, executor)
                    .addOnCompleteListener(executor) { task ->
                        if (!task.isSuccessful) {
                            Log.w(TAG, "ensureCastContext failed", task.exception)
                        }
                        mainHandler.post { result.success(task.isSuccessful) }
                    }
            } catch (e: Exception) {
                Log.w(TAG, "ensureCastContext failed", e)
                result.success(false)
            }
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

    /**
     * False only when no CastSession exists and MediaRouter is back on the
     * phone route: the drop seen within ~50 ms of selectRoute (2026-10-18).
     * A session still loading Dynamite keeps the Cast route selected, so it
     * stays alive. Probe failures answer true so they never abort a connect.
     */
    private fun hasCastSession(): Boolean {
        return try {
            val session = CastContext.getSharedInstance(context)
                ?.sessionManager
                ?.currentCastSession
            if (session != null) return true
            !MediaRouter.getInstance(context).selectedRoute.isDefaultOrBluetooth
        } catch (_: Exception) {
            true
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
