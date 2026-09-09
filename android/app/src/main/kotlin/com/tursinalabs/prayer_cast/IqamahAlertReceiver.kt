package com.tursinalabs.prayer_cast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires the iqamah nudge notification (no FGS / Cast). */
class IqamahAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_FIRE) return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: return
        val sound = intent.getStringExtra(EXTRA_SOUND) ?: "chime"
        val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: ""
        val scheduledAtMs = intent.getLongExtra(EXTRA_SCHEDULED_EPOCH_MS, 0L)
        val app = context.applicationContext
        IqamahAlert.showNotification(app, title, body, sound)
        if (sound != "silent" && prayer.isNotBlank()) {
            IqamahAlert.enqueuePendingChimeLog(
                app,
                prayer,
                scheduledAtMs,
                System.currentTimeMillis(),
            )
        }
        IqamahAlert.cancel(app)
    }

    companion object {
        const val ACTION_FIRE = "com.tursinalabs.prayer_cast.ACTION_IQAMAH_ALERT"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_SOUND = "sound"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_SCHEDULED_EPOCH_MS = "scheduledEpochMs"
    }
}
