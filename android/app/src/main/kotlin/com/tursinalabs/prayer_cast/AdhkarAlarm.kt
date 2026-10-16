package com.tursinalabs.prayer_cast

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Morning / evening adhkar AlarmClock.
 *
 * Separate request codes and prefs from the adzan clock and from
 * [IqamahAlert], so arming adhkar does not cancel those alarms.
 * The fire PendingIntent starts [AdzanForegroundService], the same
 * headless engine the adzan alarm uses.
 */
object AdhkarAlarm {
    private const val TAG = "AdhkarAlarm"
    private const val PREFS = "adhkar_alarm"
    private const val REQ_MORNING = 1101
    private const val REQ_EVENING = 1102
    private const val REQ_MORNING_SHOW = 1111
    private const val REQ_EVENING_SHOW = 1112

    fun schedule(context: Context, type: String, atMs: Long) {
        val request = requestCode(type) ?: return
        cancel(context, type, clearPrefs = false)

        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java)
            ?: throw IllegalStateException("AlarmManager unavailable")
        val prayer = "adhkar-$type"
        val operation = firePendingIntent(app, request, prayer, atMs)
        val show = PendingIntent.getActivity(
            app,
            showRequestCode(type),
            Intent(app, MainActivity::class.java),
            pendingFlags(),
        )
        alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(atMs, show), operation)
        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(epochKey(type), atMs)
            .apply()
        Log.i(TAG, "Armed adhkar $type at $atMs")
    }

    fun cancel(context: Context, type: String, clearPrefs: Boolean = true) {
        val request = requestCode(type) ?: return
        val app = context.applicationContext
        val alarmManager = app.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(firePendingIntent(app, request, "adhkar-$type", 0L))
        if (clearPrefs) {
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(epochKey(type))
                .apply()
        }
    }

    fun rearmFromPrefsIfFuture(context: Context): Boolean {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        var armed = false
        for (type in listOf("morning", "evening")) {
            val epoch = prefs.getLong(epochKey(type), 0L)
            if (epoch <= now) continue
            try {
                schedule(app, type, epoch)
                armed = true
            } catch (e: Exception) {
                Log.w(TAG, "Rearm $type failed", e)
            }
        }
        return armed
    }

    fun rememberPending(
        context: Context,
        prayer: String,
        scheduledEpochMs: Long,
        firedAtMs: Long,
        voiceId: String,
    ) {
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_PRAYER, prayer)
            .putLong(KEY_PENDING_EPOCH, scheduledEpochMs)
            .putLong(KEY_PENDING_FIRED, firedAtMs)
            .putString(KEY_PENDING_VOICE, voiceId)
            .apply()
    }

    /** Reads and clears a fire that arrived before Dart listened. */
    fun takePending(context: Context): Map<String, Any>? {
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val prayer = prefs.getString(KEY_PENDING_PRAYER, null)
        if (prayer.isNullOrEmpty()) return null
        val payload = mapOf(
            "prayer" to prayer,
            "scheduledEpochMs" to prefs.getLong(KEY_PENDING_EPOCH, 0L),
            "firedAtMs" to prefs.getLong(KEY_PENDING_FIRED, 0L),
            "voiceId" to (prefs.getString(KEY_PENDING_VOICE, "") ?: ""),
        )
        prefs.edit()
            .remove(KEY_PENDING_PRAYER)
            .remove(KEY_PENDING_EPOCH)
            .remove(KEY_PENDING_FIRED)
            .remove(KEY_PENDING_VOICE)
            .apply()
        return payload
    }

    private fun firePendingIntent(
        context: Context,
        requestCode: Int,
        prayer: String,
        epochMs: Long,
    ): PendingIntent {
        val fire = Intent(context, AdzanForegroundService::class.java).apply {
            action = AdzanForegroundService.ACTION_START
            putExtra(ExactAlarmPlugin.EXTRA_PRAYER, prayer)
            putExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, epochMs)
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, requestCode, fire, pendingFlags())
        } else {
            PendingIntent.getService(context, requestCode, fire, pendingFlags())
        }
    }

    private fun requestCode(type: String): Int? = when (type) {
        "morning" -> REQ_MORNING
        "evening" -> REQ_EVENING
        else -> null
    }

    private fun showRequestCode(type: String): Int = when (type) {
        "morning" -> REQ_MORNING_SHOW
        else -> REQ_EVENING_SHOW
    }

    private fun epochKey(type: String): String = "${type}_epoch"

    private fun pendingFlags(): Int {
        val base = PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            base or PendingIntent.FLAG_IMMUTABLE
        } else {
            base
        }
    }

    private const val KEY_PENDING_PRAYER = "pending_prayer"
    private const val KEY_PENDING_EPOCH = "pending_epoch"
    private const val KEY_PENDING_FIRED = "pending_fired"
    private const val KEY_PENDING_VOICE = "pending_voice"
}
