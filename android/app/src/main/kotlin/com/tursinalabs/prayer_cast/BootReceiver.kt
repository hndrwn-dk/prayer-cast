package com.tursinalabs.prayer_cast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms the exact alarm after reboot (spec §5.5).
 *
 * RECEIVE_BOOT_COMPLETED is declared in the manifest; without this receiver
 * every alarm is lost on reboot. Uses SharedPreferences written by
 * [ExactAlarmPlugin.armAlarmClock] — no Dart engine required.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        val armed = ExactAlarmPlugin.rearmFromPrefsIfFuture(context.applicationContext)
        Log.i(TAG, if (armed) "Re-armed exact alarm from prefs" else "No future alarm to re-arm")
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
