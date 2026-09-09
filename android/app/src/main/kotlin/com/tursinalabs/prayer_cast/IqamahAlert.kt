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
 * Post-adhan iqamah nudge. Notification only — no FGS, no Cast, no Dart.
 */
object IqamahAlert {
    private const val PREFS = "iqamah_alert"
    private const val KEY_EPOCH = "epoch"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_SOUND = "sound"
    private const val KEY_PRAYER = "prayer"
    private const val KEY_PENDING_LOGS = "pending_chime_logs"
    private const val REQ_IQAMAH = 1005
    private const val CHANNEL_CHIME = "iqamah_alert_chime"
    private const val CHANNEL_SILENT = "iqamah_alert_silent"
    private const val NOTIFICATION_ID = 2003

    fun schedule(
        context: Context,
        epochMs: Long,
        title: String,
        body: String,
        prayer: String,
        sound: String = "chime",
    ) {
        cancel(context, clearPrefs = false)

        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java)
            ?: throw IllegalStateException("AlarmManager unavailable")

        val fireIntent = Intent(app, IqamahAlertReceiver::class.java).apply {
            action = IqamahAlertReceiver.ACTION_FIRE
            putExtra(IqamahAlertReceiver.EXTRA_TITLE, title)
            putExtra(IqamahAlertReceiver.EXTRA_BODY, body)
            putExtra(IqamahAlertReceiver.EXTRA_SOUND, sound)
            putExtra(IqamahAlertReceiver.EXTRA_PRAYER, prayer)
            putExtra(IqamahAlertReceiver.EXTRA_SCHEDULED_EPOCH_MS, epochMs)
        }
        val operation = PendingIntent.getBroadcast(
            app,
            REQ_IQAMAH,
            fireIntent,
            pendingFlags(),
        )

        val showIntent = PendingIntent.getActivity(
            app,
            REQ_IQAMAH + 1,
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
            .putString(KEY_PRAYER, prayer)
            .apply()
    }

    fun cancel(context: Context, clearPrefs: Boolean = true) {
        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java) ?: return
        val fireIntent = Intent(app, IqamahAlertReceiver::class.java).apply {
            action = IqamahAlertReceiver.ACTION_FIRE
        }
        val operation = PendingIntent.getBroadcast(
            app,
            REQ_IQAMAH,
            fireIntent,
            pendingFlags(),
        )
        alarmManager.cancel(operation)
        if (clearPrefs) {
            // Keep pending chime logs — only clear the armed alarm fields.
            val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val pending = prefs.getString(KEY_PENDING_LOGS, null)
            prefs.edit().clear().apply()
            if (pending != null) {
                prefs.edit().putString(KEY_PENDING_LOGS, pending).apply()
            }
        }
    }

    fun rearmFromPrefsIfFuture(context: Context): Boolean {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_EPOCH)) return false
        val epochMs = prefs.getLong(KEY_EPOCH, 0L)
        if (epochMs <= System.currentTimeMillis()) return false
        val title = prefs.getString(KEY_TITLE, null) ?: return false
        val body = prefs.getString(KEY_BODY, null) ?: return false
        val sound = prefs.getString(KEY_SOUND, "chime") ?: "chime"
        val prayer = prefs.getString(KEY_PRAYER, "") ?: ""
        return try {
            schedule(app, epochMs, title, body, prayer, sound)
            true
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    /** Record a chime fire for Dart to drain into delivery_log (silent = skip). */
    fun enqueuePendingChimeLog(
        context: Context,
        prayer: String,
        scheduledAtMs: Long,
        firedAtMs: Long,
    ) {
        if (prayer.isBlank()) return
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            org.json.JSONArray(prefs.getString(KEY_PENDING_LOGS, "[]"))
        } catch (_: Exception) {
            org.json.JSONArray()
        }
        arr.put(
            org.json.JSONObject()
                .put("prayer", prayer)
                .put("scheduledAtMs", scheduledAtMs)
                .put("firedAtMs", firedAtMs),
        )
        prefs.edit().putString(KEY_PENDING_LOGS, arr.toString()).apply()
    }

    fun drainPendingChimeLogs(context: Context): List<Map<String, Any>> {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_LOGS, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING_LOGS).apply()
        val arr = try {
            org.json.JSONArray(raw)
        } catch (_: Exception) {
            return emptyList()
        }
        val out = ArrayList<Map<String, Any>>(arr.length())
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            val prayer = obj.optString("prayer", "")
            if (prayer.isBlank()) continue
            out.add(
                mapOf(
                    "prayer" to prayer,
                    "scheduledAtMs" to obj.optLong("scheduledAtMs", 0L),
                    "firedAtMs" to obj.optLong("firedAtMs", 0L),
                ),
            )
        }
        return out
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
            .setPriority(
                if (sound == "silent") {
                    NotificationCompat.PRIORITY_DEFAULT
                } else {
                    NotificationCompat.PRIORITY_HIGH
                },
            )
            .build()
        val manager = app.getSystemService(NotificationManager::class.java) ?: return
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun ensureChannel(context: Context, sound: String): String {
        val silent = sound == "silent"
        val channelId = if (silent) CHANNEL_SILENT else CHANNEL_CHIME
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return channelId
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return channelId
        val channel = NotificationChannel(
            channelId,
            "Iqamah reminders",
            if (silent) {
                NotificationManager.IMPORTANCE_DEFAULT
            } else {
                NotificationManager.IMPORTANCE_HIGH
            },
        ).apply {
            description = "Reminder after adhan to stand for prayer"
            if (silent) {
                setSound(null, null)
            } else {
                val uri = Uri.parse(
                    "android.resource://${context.packageName}/${R.raw.beep}",
                )
                setSound(
                    uri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            }
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
