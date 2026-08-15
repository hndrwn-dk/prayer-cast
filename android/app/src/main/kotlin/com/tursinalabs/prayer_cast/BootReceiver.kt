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
        val armed = ExactAlarmPlugin.rearmFromPrefsIfFuture(app)
        if (armed) {
            Log.i(TAG, "Re-armed exact alarm from prefs ($action)")
            return
        }
        val retry = ExactAlarmPlugin.armRescheduleRetry(app)
        Log.i(
            TAG,
            if (retry) {
                "Armed reschedule-retry after $action (prefs had no future wake)"
            } else {
                "No future alarm to re-arm after $action"
            },
        )
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
