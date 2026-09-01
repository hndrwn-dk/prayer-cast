package com.tursinalabs.prayer_cast

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Boot-independent backstop when [BootReceiver] never runs.
 *
 * ColorOS Auto-launch / MIUI Startup Manager can swallow BOOT_COMPLETED.
 * This worker reads the same persisted epoch [BootReceiver] reads and
 * calls [ExactAlarmPlugin.healPersistedWake] — the same
 * rearm-or-[armRescheduleRetry] path, not a parallel scheduler.
 *
 * Honest limit: WorkManager itself can be delayed or dropped by the same
 * OEM autostart / battery gates. Interval is hours, not minutes, so this
 * does not become another optimization target. It reduces the miss window;
 * it does not guarantee zero missed prayers.
 *
 * Constraints are minimal (no network required) to avoid being blocked
 * by aggressive OEM background restrictions while still ensuring reasonable
 * device state for execution.
 */
class AlarmHealWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val healed = ExactAlarmPlugin.healPersistedWake(applicationContext)
        TravelLocationStore.maybeRequestReschedule(applicationContext)
        NextPrayerWidget.refresh(applicationContext)
        Log.i(TAG, if (healed) "Healed persisted wake" else "Heal no-op")
        return Result.success()
    }

    companion object {
        private const val TAG = "AlarmHealWorker"
    }
}

object AlarmHealScheduler {
    const val UNIQUE_NAME = "prayer_cast_alarm_heal"
    private const val TAG = "AlarmHealScheduler"

    fun enqueue(context: Context) {
        try {
            // Minimal constraints: no network. WorkManager can still be
            // delayed or dropped by the same OEM autostart gate.
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .setRequiresBatteryNotLow(false)
                .setRequiresCharging(false)
                .setRequiresDeviceIdle(false)
                .build()

            val request = PeriodicWorkRequestBuilder<AlarmHealWorker>(
                4,
                TimeUnit.HOURS,
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    UNIQUE_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request,
                )
        } catch (e: Exception) {
            Log.w(TAG, "WorkManager enqueue failed — BootReceiver / next open still heal", e)
        }
    }
}
