package com.tursinalabs.prayer_cast

import android.content.Context
import android.util.Log
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
 */
object PrayerCastFlutter {
    const val ENGINE_ID = "prayer_cast_delivery"
    private const val TAG = "PrayerCastFlutter"

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)

    fun registerAppPlugins(engine: FlutterEngine, context: Context) {
        ExactAlarmPlugin.registerWith(engine, context)
        OemBatteryPlugin.registerWith(engine, context)
        DeviceConditionsPlugin.registerWith(engine, context)
        NetworkPrefixPlugin.registerWith(engine)
        CastReadyPlugin.registerWith(engine, context)
        // Ensure WorkManager heal scheduler is running on every app start
        AlarmHealScheduler.enqueue(context)
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
        val app = context.applicationContext
        Log.i(TAG, "Starting headless FlutterEngine for adzan delivery")
        val engine = FlutterEngine(app)
        registerAppPlugins(engine, app)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }
}
