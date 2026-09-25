package com.tursinalabs.prayer_cast

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeliveryEnginePolicyTest {
    @Test
    fun destroyedEngineIsNeverReattached() {
        assertEquals(
            DeliveryEnginePolicy.Reuse.CreateFresh,
            DeliveryEnginePolicy.reuse(
                hasCached = true,
                destroyed = true,
                deliveryReady = true,
                ageMs = 1_000,
            ),
        )
    }

    @Test
    fun readyEngineIsReused() {
        assertEquals(
            DeliveryEnginePolicy.Reuse.AttachExisting,
            DeliveryEnginePolicy.reuse(
                hasCached = true,
                destroyed = false,
                deliveryReady = true,
                ageMs = 60_000,
            ),
        )
    }

    @Test
    fun youngBootIsNotDiscarded() {
        assertEquals(
            DeliveryEnginePolicy.Reuse.AttachExisting,
            DeliveryEnginePolicy.reuse(
                hasCached = true,
                destroyed = false,
                deliveryReady = false,
                ageMs = DeliveryEnginePolicy.HANG_BUDGET_MS,
            ),
        )
    }

    @Test
    fun hungBootIsDiscardedSoAFreshEngineCanPlay() {
        assertEquals(
            DeliveryEnginePolicy.Reuse.DiscardAndCreate,
            DeliveryEnginePolicy.reuse(
                hasCached = true,
                destroyed = false,
                deliveryReady = false,
                ageMs = DeliveryEnginePolicy.HANG_BUDGET_MS + 1,
            ),
        )
    }

    @Test
    fun activityMustNotDestroyTheSharedEngine() {
        assertFalse(DeliveryEnginePolicy.destroyEngineWithHost())
    }

    @Test
    fun hangRestartSkipsWhileTheUiIsAttached() {
        assertFalse(
            DeliveryEnginePolicy.shouldHangRestart(
                deliveryReady = false,
                uiAttached = true,
                restarts = 0,
                hasCached = true,
            ),
        )
        assertTrue(
            DeliveryEnginePolicy.shouldHangRestart(
                deliveryReady = false,
                uiAttached = false,
                restarts = 0,
                hasCached = true,
            ),
        )
        assertFalse(
            DeliveryEnginePolicy.shouldHangRestart(
                deliveryReady = false,
                uiAttached = false,
                restarts = DeliveryEnginePolicy.MAX_HANG_RESTARTS,
                hasCached = true,
            ),
        )
    }
}
