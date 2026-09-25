package com.tursinalabs.prayer_cast

/**
 * When [MainActivity] may attach a FlutterView to the shared delivery engine.
 *
 * The notification tap that late-played Dhuhr on 2026-09-14 handed the
 * activity an engine Flutter had already destroyed. The cache still held
 * it, [setViewportMetrics] ran on a detached JNI, and the process died.
 */
object DeliveryEnginePolicy {
    /** Past this, a boot that never called markDeliveryReady is hung. */
    const val HANG_BUDGET_MS = 8_000L

    /** One headless restart. A second hang waits for the next UI open. */
    const val MAX_HANG_RESTARTS = 1

    enum class Reuse {
        /** Attach the cached engine. Do not destroy it. */
        AttachExisting,

        /** Destroy the cached engine, then let Flutter create a new one. */
        DiscardAndCreate,

        /** Nothing usable is cached. Let Flutter create a new one. */
        CreateFresh,
    }

    fun reuse(
        hasCached: Boolean,
        destroyed: Boolean,
        deliveryReady: Boolean,
        ageMs: Long,
    ): Reuse {
        if (!hasCached || destroyed) return Reuse.CreateFresh
        if (deliveryReady) return Reuse.AttachExisting
        if (ageMs in 0..HANG_BUDGET_MS) return Reuse.AttachExisting
        return Reuse.DiscardAndCreate
    }

    /**
     * The activity must not destroy the shared engine. Flutter only drops a
     * destroyed engine from [io.flutter.embedding.engine.FlutterEngineCache]
     * when getCachedEngineId() is set. We cache via provideFlutterEngine, so
     * a host destroy leaves a detached engine for the next notification tap.
     */
    fun destroyEngineWithHost(): Boolean = false

    fun shouldHangRestart(
        deliveryReady: Boolean,
        uiAttached: Boolean,
        restarts: Int,
        hasCached: Boolean,
    ): Boolean {
        if (deliveryReady || uiAttached || !hasCached) return false
        return restarts < MAX_HANG_RESTARTS
    }
}
