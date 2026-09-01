package com.tursinalabs.prayer_cast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms the exact alarm after reboot or [adb install -r] (spec §5.5).
 *
 * Package replace force-stops the app and drops AlarmManager clocks.
 * If prefs still hold a future wake, re-arm natively. If the stored
 * epoch is already past (Asr fired, Dart never rescheduled Maghrib),
 * arm a short [reschedule-retry] so FGS + Dart can schedule the next
 * real prayer without waiting for the user to open the app.
 *
 * ColorOS / MIUI / Funtouch "Auto-launch" can drop BOOT_COMPLETED
 * entirely. [AlarmHealWorker] is the boot-independent backstop; this
 * receiver stays the faster path when the broadcast is delivered.
 *
 * IMPORTANT: On devices with aggressive OEM restrictions, BOOT_COMPLETED
 * may be silently dropped. The WorkManager heal worker runs every 4 hours
 * as a fallback, but this cannot guarantee zero missed prayers. Users on
 * restrictive OEMs should enable Auto-launch permission via the in-app prompt.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val app = context.applicationContext
        // Ensure WorkManager heal worker is running (may be cleared by OEM)
        AlarmHealScheduler.enqueue(app)
        val healed = ExactAlarmPlugin.healPersistedWake(app)
        val preHealed = PrePrayerAlert.rearmFromPrefsIfFuture(app)
        NextPrayerWidget.refresh(app)
        Log.i(
            TAG,
            when {
                healed && preHealed -> "Healed wake + pre-alert after $action"
                healed -> "Healed persisted wake after $action"
                preHealed -> "Healed pre-alert after $action"
                else -> "No future alarm to re-arm after $action"
            },
        )
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
