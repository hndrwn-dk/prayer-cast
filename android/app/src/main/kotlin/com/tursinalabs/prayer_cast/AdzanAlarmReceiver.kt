package com.tursinalabs.prayer_cast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Legacy AlarmClock → FGS hop.
 *
 * New arms use [PendingIntent.getForegroundService] straight to
 * [AdzanForegroundService] (cached-apps freezer can drop this broadcast
 * when the process has been frozen for hours). Kept so an alarm armed
 * before that migration can still start delivery.
 */
class AdzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_FIRE) return

        val prayer = intent.getStringExtra(ExactAlarmPlugin.EXTRA_PRAYER) ?: "unknown"
        val scheduledEpochMs =
            intent.getLongExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, 0L)
        val voiceId = intent.getStringExtra(ExactAlarmPlugin.EXTRA_VOICE_ID) ?: ""
        val firedAtMs = System.currentTimeMillis()

        val serviceIntent = Intent(context, AdzanForegroundService::class.java).apply {
            action = AdzanForegroundService.ACTION_START
            putExtra(ExactAlarmPlugin.EXTRA_PRAYER, prayer)
            putExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, scheduledEpochMs)
            putExtra(ExactAlarmPlugin.EXTRA_VOICE_ID, voiceId)
            putExtra(EXTRA_FIRED_AT_MS, firedAtMs)
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }

    companion object {
        const val ACTION_FIRE = "com.tursinalabs.prayer_cast.ACTION_ADZAN_ALARM"
        const val EXTRA_FIRED_AT_MS = "firedAtMs"
    }
}
