package com.tursinalabs.prayer_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.HashSet

/**
 * Shared FlutterEngine for alarm wake. Pixel / API 34+ BAL-blocks
 * [MainActivity] from [AdzanForegroundService] even with FSI + creator
 * BAL opt-in when the PendingIntent sender and creator share a UID
 * (`resultIfPiCreatorAllowsBal: BAL_BLOCK`, `autoOptInReason: sameUid`).
 * Dart must still run in the FGS so Cast happens at azan, not when the
 * user later opens the app.
 *
 * A notification tap must not attach a FlutterView to an engine Flutter
 * already destroyed. That is the 2026-09-14 Dhuhr crash
 * (`FlutterJNI is not attached` in `setViewportMetrics`): the activity
 * closed before [markDeliveryReady], Flutter destroyed the engine, the
 * cache still held it, and the next tap laid that corpse out and died.
 * Playback then waited for a fresh process.
 */
object PrayerCastFlutter {
    const val ENGINE_ID = "prayer_cast_delivery"
    private const val TAG = "PrayerCastFlutter"

    @Volatile
    private var deliveryReady: Boolean = false

    @Volatile
    private var uiAttached: Boolean = false

    private var startedAtElapsed: Long = 0L
    private var hangRestarts: Int = 0
    private var hangContext: Context? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val destroyedIds = HashSet<Int>()

    private val hangRestart = Runnable { recoverHungEngine() }

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)

    fun isDeliveryReady(): Boolean = deliveryReady

    fun onUiAttached() {
        uiAttached = true
        mainHandler.removeCallbacks(hangRestart)
    }

    /**
     * The activity is gone. If Dart never became ready, restart the
     * headless engine after the view has detached so closing the splash
     * does not cancel the pending fire.
     */
    fun onUiDetached(context: Context) {
        uiAttached = false
        if (deliveryReady) return
        val remaining = DeliveryEnginePolicy.HANG_BUDGET_MS - ageMs()
        armHangWatch(context, remaining.coerceAtLeast(0L))
    }

    fun markDeliveryReady() {
        val engine = cached()
        if (engine == null || isDestroyed(engine)) {
            Log.w(TAG, "Ignoring markDeliveryReady: no live engine")
            return
        }
        deliveryReady = true
        hangRestarts = 0
        mainHandler.removeCallbacks(hangRestart)
        Log.i(TAG, "Dart delivery ready")
    }

    /**
     * Engine for [MainActivity]. Never returns an engine whose JNI is
     * already detached. A still-booting engine is reused so the tap does
     * not abort delivery. A hung boot is discarded so a fresh Dart can
     * consume the persisted pending fire.
     */
    fun engineForActivity(): FlutterEngine? {
        val engine = cached()
        val decision = DeliveryEnginePolicy.reuse(
            hasCached = engine != null,
            destroyed = engine != null && isDestroyed(engine),
            deliveryReady = deliveryReady,
            ageMs = ageMs(),
        )
        return when (decision) {
            DeliveryEnginePolicy.Reuse.CreateFresh -> {
                if (engine != null) dropDestroyed(engine)
                null
            }
            DeliveryEnginePolicy.Reuse.AttachExisting -> engine
            DeliveryEnginePolicy.Reuse.DiscardAndCreate -> {
                discardHungEngine(
                    "MainActivity opened after ${ageMs()}ms without delivery ready",
                )
                null
            }
        }
    }

    fun discardHungEngine(reason: String) {
        val engine = cached() ?: return
        Log.w(TAG, "Discarding hung FlutterEngine: $reason")
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        deliveryReady = false
        ExactAlarmPlugin.detachInstance()
        if (isDestroyed(engine)) return
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
            watch(engine)
            startedAtElapsed = SystemClock.elapsedRealtime()
        }
    }

    /**
     * Start Dart [main] in this process if no engine is cached.
     * Call after [ExactAlarmPlugin.emitFromBackground] so [pendingFire]
     * is waiting when the coordinator listens.
     */
    fun ensureStarted(context: Context): FlutterEngine {
        cached()?.let { engine ->
            if (!isDestroyed(engine)) return engine
            dropDestroyed(engine)
        }
        deliveryReady = false
        val app = context.applicationContext
        Log.i(TAG, "Starting headless FlutterEngine for adzan delivery")
        val engine = FlutterEngine(app)
        watch(engine)
        startedAtElapsed = SystemClock.elapsedRealtime()
        registerAppPlugins(engine, app)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        armHangWatch(app, DeliveryEnginePolicy.HANG_BUDGET_MS)
        warmCastOffThread(app)
        return engine
    }

    private fun watch(engine: FlutterEngine) {
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() {}

            override fun onEngineWillDestroy() {
                noteDestroyed(engine)
            }
        })
    }

    private fun isDestroyed(engine: FlutterEngine): Boolean {
        return destroyedIds.contains(System.identityHashCode(engine))
    }

    private fun noteDestroyed(engine: FlutterEngine) {
        destroyedIds.add(System.identityHashCode(engine))
        if (cached() === engine) {
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }
        deliveryReady = false
        ExactAlarmPlugin.detachInstance()
        Log.w(TAG, "Delivery engine destroyed; cache cleared")
    }

    private fun dropDestroyed(engine: FlutterEngine) {
        if (cached() === engine) {
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }
        deliveryReady = false
    }

    private fun ageMs(): Long {
        if (startedAtElapsed == 0L) return 0L
        return SystemClock.elapsedRealtime() - startedAtElapsed
    }

    private fun armHangWatch(context: Context, delayMs: Long) {
        hangContext = context.applicationContext
        mainHandler.removeCallbacks(hangRestart)
        mainHandler.postDelayed(hangRestart, delayMs)
    }

    private fun recoverHungEngine() {
        val context = hangContext ?: return
        if (!DeliveryEnginePolicy.shouldHangRestart(
                deliveryReady = deliveryReady,
                uiAttached = uiAttached,
                restarts = hangRestarts,
                hasCached = cached()?.let { !isDestroyed(it) } == true,
            )
        ) {
            return
        }
        val age = ageMs()
        if (age < DeliveryEnginePolicy.HANG_BUDGET_MS) {
            armHangWatch(context, DeliveryEnginePolicy.HANG_BUDGET_MS - age)
            return
        }
        hangRestarts += 1
        Log.w(TAG, "Restarting hung headless engine (attempt $hangRestarts)")
        discardHungEngine(
            "headless boot exceeded ${DeliveryEnginePolicy.HANG_BUDGET_MS}ms",
        )
        ensureStarted(context)
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
