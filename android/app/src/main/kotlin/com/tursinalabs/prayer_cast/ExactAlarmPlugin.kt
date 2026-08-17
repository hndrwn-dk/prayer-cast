package com.tursinalabs.prayer_cast

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge for AlarmManager.setAlarmClock (spec §5.5).
 *
 * Schedules only the next alarm. Does NOT use USE_EXACT_ALARM — runtime
 * SCHEDULE_EXACT_ALARM permission is requested via settings intent.
 *
 * AlarmManager arming is on the companion so [BootReceiver] can re-arm from
 * SharedPreferences without a live Dart engine.
 */
class ExactAlarmPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var channel: MethodChannel? = null

    fun attachChannel(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun notifyStopLocalPlayback() {
        channel?.invokeMethod("stopLocalPlayback", null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleNext" -> {
                val epochMs = call.argument<Number>("epochMs")?.toLong()
                val prayer = call.argument<String>("prayer")
                val voiceId = call.argument<String>("voiceId")
                if (epochMs == null || prayer == null || voiceId == null) {
                    result.error(
                        "bad_args",
                        "epochMs, prayer, and voiceId required",
                        null,
                    )
                    return
                }
                try {
                    armAlarmClock(context, epochMs, prayer, voiceId)
                    result.success(null)
                } catch (e: SecurityException) {
                    result.error("no_permission", e.message, null)
                } catch (e: Exception) {
                    result.error("schedule_failed", e.message, null)
                }
            }
            "cancel" -> {
                cancelAlarmClock(context)
                result.success(null)
            }
            "canScheduleExactAlarms" -> {
                result.success(canScheduleExactAlarms(context))
            }
            "requestExactAlarmPermission" -> {
                requestExactAlarmPermission(context)
                result.success(null)
            }
            "stopForegroundService" -> {
                val intent = Intent(context, AdzanForegroundService::class.java)
                context.stopService(intent)
                result.success(null)
            }
            "showPhonePlaybackControls" -> {
                val prayer = call.argument<String>("prayer") ?: "adzan"
                AdzanForegroundService.showPhonePlayback(context, prayer)
                result.success(null)
            }
            "getScheduled" -> {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                if (!prefs.contains(KEY_EPOCH)) {
                    result.success(null)
                    return
                }
                result.success(
                    mapOf(
                        "epochMs" to prefs.getLong(KEY_EPOCH, 0L),
                        "prayer" to (prefs.getString(KEY_PRAYER, "") ?: ""),
                        "voiceId" to (prefs.getString(KEY_VOICE_ID, "") ?: ""),
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Deliver any pending fire that arrived before Dart listened
        // (in-memory, or persisted across a process restart within grace).
        val fire = pendingFire ?: readPersistedPendingFire(context)
        fire?.let {
            events?.success(it)
            pendingFire = null
            clearPersistedPendingFire(context)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun emitAlarmFired(
        prayer: String,
        scheduledEpochMs: Long,
        firedAtMs: Long,
        voiceId: String,
    ) {
        val payload = mapOf(
            "prayer" to prayer,
            "scheduledEpochMs" to scheduledEpochMs,
            "firedAtMs" to firedAtMs,
            "voiceId" to voiceId,
        )
        persistPendingFire(context, payload)
        val sink = eventSink
        if (sink != null) {
            sink.success(payload)
            pendingFire = null
            clearPersistedPendingFire(context)
        } else {
            pendingFire = payload
        }
    }

    companion object {
        const val CHANNEL = "prayer_cast/exact_alarm"
        const val EVENT_CHANNEL = "prayer_cast/exact_alarm_events"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_SCHEDULED_EPOCH_MS = "scheduledEpochMs"
        const val EXTRA_VOICE_ID = "voiceId"
        const val PREFS = "exact_alarm"
        const val KEY_PRAYER = "prayer"
        const val KEY_EPOCH = "epoch"
        const val KEY_VOICE_ID = "voiceId"
        const val RESCHEDULE_RETRY_PRAYER = "reschedule-retry"
        private const val RESCHEDULE_RETRY_DELAY_MS = 15_000L
        private const val REQ_FIRE = 1001
        private const val REQ_SHOW = 1002

        @Volatile
        private var instance: ExactAlarmPlugin? = null

        @Volatile
        private var pendingFire: Map<String, Any>? = null

        fun requestStopLocalPlayback() {
            instance?.notifyStopLocalPlayback()
        }

        fun registerWith(flutterEngine: FlutterEngine, context: Context): ExactAlarmPlugin {
            val plugin = ExactAlarmPlugin(context.applicationContext)
            instance = plugin
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).also { method ->
                plugin.attachChannel(method)
                method.setMethodCallHandler(plugin)
            }
            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                EVENT_CHANNEL,
            ).setStreamHandler(plugin)
            return plugin
        }

        fun emitFromBackground(
            context: Context,
            prayer: String,
            scheduledEpochMs: Long,
            firedAtMs: Long,
            voiceId: String,
        ) {
            val payload = mapOf(
                "prayer" to prayer,
                "scheduledEpochMs" to scheduledEpochMs,
                "firedAtMs" to firedAtMs,
                "voiceId" to voiceId,
            )
            persistPendingFire(context, payload)
            instance?.emitAlarmFired(prayer, scheduledEpochMs, firedAtMs, voiceId)
                ?: run { pendingFire = payload }
        }

        private const val KEY_PENDING_PRAYER = "pending_prayer"
        private const val KEY_PENDING_EPOCH = "pending_epoch"
        private const val KEY_PENDING_FIRED = "pending_fired"
        private const val KEY_PENDING_VOICE = "pending_voice"

        @JvmStatic
        fun persistPendingFire(context: Context, payload: Map<String, Any>) {
            val prayer = payload["prayer"] as? String ?: return
            val epoch = (payload["scheduledEpochMs"] as? Number)?.toLong() ?: return
            val fired = (payload["firedAtMs"] as? Number)?.toLong() ?: return
            val voice = payload["voiceId"] as? String ?: ""
            context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_PRAYER, prayer)
                .putLong(KEY_PENDING_EPOCH, epoch)
                .putLong(KEY_PENDING_FIRED, fired)
                .putString(KEY_PENDING_VOICE, voice)
                .apply()
        }

        @JvmStatic
        fun readPersistedPendingFire(context: Context): Map<String, Any>? {
            val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val prayer = prefs.getString(KEY_PENDING_PRAYER, null) ?: return null
            if (!prefs.contains(KEY_PENDING_EPOCH) || !prefs.contains(KEY_PENDING_FIRED)) {
                return null
            }
            return mapOf(
                "prayer" to prayer,
                "scheduledEpochMs" to prefs.getLong(KEY_PENDING_EPOCH, 0L),
                "firedAtMs" to prefs.getLong(KEY_PENDING_FIRED, 0L),
                "voiceId" to (prefs.getString(KEY_PENDING_VOICE, "") ?: ""),
            )
        }

        @JvmStatic
        fun clearPersistedPendingFire(context: Context) {
            context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_PENDING_PRAYER)
                .remove(KEY_PENDING_EPOCH)
                .remove(KEY_PENDING_FIRED)
                .remove(KEY_PENDING_VOICE)
                .apply()
        }

        /**
         * Core AlarmManager.setAlarmClock arming — callable without Dart.
         * Persists prayer/epoch/voiceId for [BootReceiver] re-arm.
         */
        @JvmStatic
        fun armAlarmClock(
            context: Context,
            epochMs: Long,
            prayer: String,
            voiceId: String,
        ) {
            cancelAlarmClock(context, clearPrefs = false)

            val alarmManager = context.getSystemService(AlarmManager::class.java)
                ?: throw IllegalStateException("AlarmManager unavailable")

            val showIntent = PendingIntent.getActivity(
                context,
                REQ_SHOW,
                Intent(context, MainActivity::class.java),
                pendingFlags(),
            )

            val fireIntent = Intent(context, AdzanAlarmReceiver::class.java).apply {
                action = AdzanAlarmReceiver.ACTION_FIRE
                putExtra(EXTRA_PRAYER, prayer)
                putExtra(EXTRA_SCHEDULED_EPOCH_MS, epochMs)
                putExtra(EXTRA_VOICE_ID, voiceId)
            }
            val operation = PendingIntent.getBroadcast(
                context,
                REQ_FIRE,
                fireIntent,
                pendingFlags(),
            )

            val info = AlarmManager.AlarmClockInfo(epochMs, showIntent)
            alarmManager.setAlarmClock(info, operation)

            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PRAYER, prayer)
                .putLong(KEY_EPOCH, epochMs)
                .putString(KEY_VOICE_ID, voiceId)
                .apply()
        }

        @JvmStatic
        fun cancelAlarmClock(context: Context, clearPrefs: Boolean = true) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            val fireIntent = Intent(context, AdzanAlarmReceiver::class.java).apply {
                action = AdzanAlarmReceiver.ACTION_FIRE
            }
            val operation = PendingIntent.getBroadcast(
                context,
                REQ_FIRE,
                fireIntent,
                pendingFlags(),
            )
            alarmManager.cancel(operation)
            if (clearPrefs) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            }
        }

        /**
         * Re-arm from persisted prefs if the wake epoch is still in the future.
         * Returns true when an alarm was armed.
         *
         * If the epoch already passed (device was off through the prayer, or
         * Dart never rescheduled), [armRescheduleRetry] starts a Dart
         * reschedule without waiting for the user to open the app.
         */
        @JvmStatic
        fun rearmFromPrefsIfFuture(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val prayer = prefs.getString(KEY_PRAYER, null) ?: return false
            if (!prefs.contains(KEY_EPOCH)) return false
            val epochMs = prefs.getLong(KEY_EPOCH, 0L)
            if (epochMs <= System.currentTimeMillis()) {
                return false
            }
            // Legacy prefs may lack voiceId — empty string lets Dart fall back.
            val voiceId = prefs.getString(KEY_VOICE_ID, null) ?: ""
            return try {
                armAlarmClock(context, epochMs, prayer, voiceId)
                true
            } catch (_: SecurityException) {
                false
            } catch (_: Exception) {
                false
            }
        }

        /**
         * AlarmClock a few seconds out named `reschedule-retry`. The fire
         * starts FGS + Dart, which skips delivery and arms the next real
         * prayer. Used when reboot / package-replace prefs are already past.
         */
        @JvmStatic
        fun armRescheduleRetry(context: Context): Boolean {
            if (!canScheduleExactAlarms(context)) return false
            val epochMs = System.currentTimeMillis() + RESCHEDULE_RETRY_DELAY_MS
            return try {
                armAlarmClock(context, epochMs, RESCHEDULE_RETRY_PRAYER, "")
                true
            } catch (_: SecurityException) {
                false
            } catch (_: Exception) {
                false
            }
        }

        @JvmStatic
        fun canScheduleExactAlarms(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return false
            return alarmManager.canScheduleExactAlarms()
        }

        @JvmStatic
        fun requestExactAlarmPermission(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        private fun pendingFlags(): Int {
            return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }
    }
}
