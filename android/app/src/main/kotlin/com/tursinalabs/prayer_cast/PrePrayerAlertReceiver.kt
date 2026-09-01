package com.tursinalabs.prayer_cast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires the pre-prayer reminder notification (no FGS / Cast). */
class PrePrayerAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_FIRE) return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: return
        val sound = intent.getStringExtra(EXTRA_SOUND) ?: "beep"
        PrePrayerAlert.showNotification(context.applicationContext, title, body, sound)
        PrePrayerAlert.cancel(context.applicationContext)
    }

    companion object {
        const val ACTION_FIRE = "com.tursinalabs.prayer_cast.ACTION_PRE_PRAYER_ALERT"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_SOUND = "sound"
    }
}
