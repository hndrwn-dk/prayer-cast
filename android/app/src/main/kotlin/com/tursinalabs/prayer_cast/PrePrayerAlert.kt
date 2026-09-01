package com.tursinalabs.prayer_cast

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Lightweight pre-prayer reminder (T−10/15 min). Shows a notification only —
 * no FGS, no Cast, no Dart engine.
 */
object PrePrayerAlert {
    private const val PREFS = "pre_prayer_alert"
    private const val KEY_EPOCH = "epoch"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_SOUND = "sound"
    private const val REQ_PRE = 1003
    private const val CHANNEL_BEEP = "pre_prayer_alert_beep"
    private const val CHANNEL_TAKBIR = "pre_prayer_alert_takbir"
    private const val NOTIFICATION_ID = 2002

    fun schedule(
        context: Context,
        epochMs: Long,
        title: String,
        body: String,
        sound: String = "beep",
    ) {
        cancel(context, clearPrefs = false)

        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java)
            ?: throw IllegalStateException("AlarmManager unavailable")

        val fireIntent = Intent(app, PrePrayerAlertReceiver::class.java).apply {
            action = PrePrayerAlertReceiver.ACTION_FIRE
            putExtra(PrePrayerAlertReceiver.EXTRA_TITLE, title)
            putExtra(PrePrayerAlertReceiver.EXTRA_BODY, body)
            putExtra(PrePrayerAlertReceiver.EXTRA_SOUND, sound)
        }
        val operation = PendingIntent.getBroadcast(
            app,
            REQ_PRE,
            fireIntent,
            pendingFlags(),
        )

        val showIntent = PendingIntent.getActivity(
            app,
            REQ_PRE + 1,
            Intent(app, MainActivity::class.java),
            pendingFlags(),
        )
        val info = AlarmManager.AlarmClockInfo(epochMs, showIntent)
        alarmManager.setAlarmClock(info, operation)

        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_EPOCH, epochMs)
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .putString(KEY_SOUND, sound)
            .apply()
    }

    fun cancel(context: Context, clearPrefs: Boolean = true) {
        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java) ?: return
        val fireIntent = Intent(app, PrePrayerAlertReceiver::class.java).apply {
            action = PrePrayerAlertReceiver.ACTION_FIRE
        }
        val operation = PendingIntent.getBroadcast(
            app,
            REQ_PRE,
            fireIntent,
            pendingFlags(),
        )
        alarmManager.cancel(operation)
        if (clearPrefs) {
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        }
    }

    /** Re-arm from prefs after reboot when epoch is still in the future. */
    fun rearmFromPrefsIfFuture(context: Context): Boolean {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_EPOCH)) return false
        val epochMs = prefs.getLong(KEY_EPOCH, 0L)
        if (epochMs <= System.currentTimeMillis()) return false
        val title = prefs.getString(KEY_TITLE, null) ?: return false
        val body = prefs.getString(KEY_BODY, null) ?: return false
        val sound = prefs.getString(KEY_SOUND, "beep") ?: "beep"
        return try {
            schedule(app, epochMs, title, body, sound)
            true
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    fun showNotification(context: Context, title: String, body: String, sound: String) {
        val app = context.applicationContext
        val channelId = ensureChannel(app, sound)
        val launch = PendingIntent.getActivity(
            app,
            0,
            Intent(app, MainActivity::class.java),
            pendingFlags(),
        )
        val notification = NotificationCompat.Builder(app, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(launch)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val manager = app.getSystemService(NotificationManager::class.java) ?: return
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun ensureChannel(context: Context, sound: String): String {
        val channelId = if (sound == "takbir") CHANNEL_TAKBIR else CHANNEL_BEEP
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return channelId
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return channelId
        val rawId = if (sound == "takbir") R.raw.takbir else R.raw.beep
        val uri = Uri.parse("android.resource://${context.packageName}/$rawId")
        val channel = NotificationChannel(
            channelId,
            "Pre-prayer reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Reminder before prayer time"
            setSound(
                uri,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
        manager.createNotificationChannel(channel)
        return channelId
    }

    private fun pendingFlags(): Int {
        val base = PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            base or PendingIntent.FLAG_IMMUTABLE
        } else {
            base
        }
    }
}
