package com.tursinalabs.prayer_cast

import android.content.Context
import android.util.Log
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Shared FlutterEngine for alarm wake. Pixel / API 34+ BAL-blocks
 * [MainActivity] from [AdzanForegroundService] even with FSI + creator
 * BAL opt-in when the PendingIntent sender and creator share a UID
 * (`resultIfPiCreatorAllowsBal: BAL_BLOCK`, `autoOptInReason: sameUid`).
 * Dart must still run in the FGS so Cast happens at azan, not when the
 * user later opens the app.
 *
 * If Dart never reaches [markDeliveryReady] (stuck before coordinator
 * listen), [engineForActivity] discards that hung engine so tapping the
 * notification starts a fresh Dart that can still consume the persisted
 * pending fire — otherwise splash stays forever and adhan never plays.
 */
object PrayerCastFlutter {
    const val ENGINE_ID = "prayer_cast_delivery"
    private const val TAG = "PrayerCastFlutter"

    @Volatile
    private var deliveryReady: Boolean = false

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)

    fun isDeliveryReady(): Boolean = deliveryReady

    fun markDeliveryReady() {
        deliveryReady = true
        Log.i(TAG, "Dart delivery ready")
    }

    /**
     * Engine for [MainActivity]. Reuse only after Dart marked ready.
     * Otherwise destroy the hung FGS engine and return null so Flutter
     * creates a fresh one (persisted pendingFire still on disk).
     */
    fun engineForActivity(): FlutterEngine? {
        if (deliveryReady) {
            return cached()
        }
        discardHungEngine("MainActivity opened before delivery ready")
        return null
    }

    fun discardHungEngine(reason: String) {
        val engine = cached() ?: return
        Log.w(TAG, "Discarding hung FlutterEngine: $reason")
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        deliveryReady = false
        ExactAlarmPlugin.detachInstance()
        try {
            engine.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "engine.destroy failed", e)
        }
    }

    fun registerAppPlugins(engine: FlutterEngine, context: Context) {
        ExactAlarmPlugin.registerWith(engine, context)
        OemBatteryPlugin.registerWith(engine, context)
        DeviceConditionsPlugin.registerWith(engine, context)
        NetworkPrefixPlugin.registerWith(engine)
        CastReadyPlugin.registerWith(engine, context)
        // WorkManager off the engine-start thread — can block FGS / splash.
        val app = context.applicationContext
        Thread({
            TravelLocationStore.disable(app)
            AlarmHealScheduler.enqueue(app)
        }, "prayer-cast-wm").start()
    }

    fun cacheIfAbsent(engine: FlutterEngine) {
        if (cached() == null) {
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        }
    }

    /**
     * Start Dart [main] in this process if no engine is cached.
     * Call after [ExactAlarmPlugin.emitFromBackground] so [pendingFire]
     * is waiting when the coordinator listens.
     */
    fun ensureStarted(context: Context): FlutterEngine {
        cached()?.let { return it }
        deliveryReady = false
        val app = context.applicationContext
        Log.i(TAG, "Starting headless FlutterEngine for adzan delivery")
        val engine = FlutterEngine(app)
        registerAppPlugins(engine, app)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        warmCastOffThread(app)
        return engine
    }

    /**
     * Load GMS Cast on a worker thread. Do not call the Dart Cast plugin
     * here — that can block the Flutter UI isolate before [runApp].
     */
    private fun warmCastOffThread(context: Context) {
        Thread({
            try {
                CastContext.getSharedInstance(context)
            } catch (e: Exception) {
                Log.w(TAG, "Cast warm-up skipped", e)
            }
        }, "prayer-cast-cast-warm").start()
    }
}
