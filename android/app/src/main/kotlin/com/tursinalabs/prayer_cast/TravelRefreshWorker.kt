package com.tursinalabs.prayer_cast

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager

/**
 * Leftover WorkManager class from the removed auto-travel GPS feature.
 * [doWork] is a no-op. [TravelLocationStore.disable] cancels queued runs.
 */
class TravelRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result = Result.success()
}

object TravelLocationStore {
    const val PREFS = "travel_location"
    const val KEY_ENABLED = "enabled"
    private const val TAG = "TravelLocation"
    private const val UNIQUE_WORK = "prayer_cast_travel_refresh"

    /** Always off. City is set by the user on Prayer times. */
    fun disable(context: Context) {
        val app = context.applicationContext
        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .apply()
        try {
            WorkManager.getInstance(app).cancelUniqueWork(UNIQUE_WORK)
        } catch (e: Exception) {
            Log.w(TAG, "cancel travel work failed", e)
        }
    }
}
