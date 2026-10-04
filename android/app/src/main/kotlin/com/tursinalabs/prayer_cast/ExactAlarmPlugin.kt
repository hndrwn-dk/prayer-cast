package com.tursinalabs.prayer_cast

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * MethodChannel bridge for AlarmManager.setAlarmClock (spec §5.5).
 *
 * Schedules only the next alarm. Does NOT use USE_EXACT_ALARM — runtime
 * SCHEDULE_EXACT_ALARM permission is requested via settings intent.
 *
 * The AlarmClock operation targets [AdzanForegroundService] directly
 * ([PendingIntent.getForegroundService]). Routing through a
 * BroadcastReceiver first can drop delivery when the process is in the
 * cached-apps freezer (Pixel Maghrib 2026-10-04: Asr OK while warm,
 * Maghrib silent while frozen until the user opened the app).
 *
 * AlarmManager arming is on the companion so [BootReceiver] can re-arm from
 * SharedPreferences without a live Dart engine.
 */
class ExactAlarmPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var channel: MethodChannel? = null
    private var activityRef: WeakReference<Activity>? = null

    fun attachChannel(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun attachActivity(activity: Activity?) {
        activityRef = activity?.let { WeakReference(it) }
    }

    fun hostActivity(): Activity? = activityRef?.get()

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
                try {
                    requestExactAlarmPermission(
                        context,
                        hostActivity(),
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("request_failed", e.message, null)
                }
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
            "playLocalBeep" -> {
                Thread {
                    try {
                        LocalAlarmSound.playBeep(context)
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("beep_failed", e.message, null)
                        }
                    }
                }.start()
            }
            "playLocalTakbir" -> {
                Thread {
                    try {
                        LocalAlarmSound.playTakbir(context)
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("takbir_failed", e.message, null)
                        }
                    }
                }.start()
            }
            "syncTravelLocation" -> {
                TravelLocationStore.disable(context)
                result.success(null)
            }
            "markDeliveryReady" -> {
                PrayerCastFlutter.markDeliveryReady()
                result.success(null)
            }
            "acknowledgeAlarmFire" -> {
                pendingFire = null
                clearPersistedPendingFire(context)
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
            "schedulePreAlert" -> {
                val epochMs = call.argument<Number>("epochMs")?.toLong()
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                val sound = call.argument<String>("sound") ?: "beep"
                if (epochMs == null || title == null || body == null) {
                    result.error("bad_args", "epochMs, title, and body required", null)
                    return
                }
                try {
                    PrePrayerAlert.schedule(context, epochMs, title, body, sound)
                    result.success(null)
                } catch (e: SecurityException) {
                    result.error("no_permission", e.message, null)
                } catch (e: Exception) {
                    result.error("schedule_failed", e.message, null)
                }
            }
            "cancelPreAlert" -> {
                PrePrayerAlert.cancel(context)
                result.success(null)
            }
            "scheduleIqamahReminder" -> {
                val epochMs = call.argument<Number>("epochMs")?.toLong()
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                val prayer = call.argument<String>("prayer") ?: ""
                val sound = call.argument<String>("sound") ?: "chime"
                if (epochMs == null || title == null || body == null) {
                    result.error("bad_args", "epochMs, title, and body required", null)
                    return
                }
                try {
                    IqamahAlert.schedule(context, epochMs, title, body, prayer, sound)
                    result.success(null)
                } catch (e: SecurityException) {
                    result.error("no_permission", e.message, null)
                } catch (e: Exception) {
                    result.error("schedule_failed", e.message, null)
                }
            }
            "cancelIqamahReminder" -> {
                IqamahAlert.cancel(context)
                result.success(null)
            }
            "drainPendingIqamahLogs" -> {
                result.success(IqamahAlert.drainPendingChimeLogs(context))
            }
            "showDeliveryFailureNotification" -> {
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                if (title == null || body == null) {
                    result.error("bad_args", "title and body required", null)
                    return
                }
                DeliveryFailureNotifier.show(context, title, body)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Deliver any pending fire that arrived before Dart listened
        // (in-memory, or persisted across a process restart within grace).
        // Keep the disk copy until [acknowledgeAlarmFire] so a hung FGS
        // engine can be discarded and a fresh MainActivity engine retries.
        // Prefer a real disk pending over in-memory reschedule-retry so a
        // late synthetic emit cannot hide Maghrib (etc.) at listen time.
        val disk = readPersistedPendingFire(context)
        val diskPrayer = disk?.get("prayer") as? String
        val fire = if (diskPrayer != null &&
            diskPrayer.isNotEmpty() &&
            diskPrayer != RESCHEDULE_RETRY_PRAYER
        ) {
            disk
        } else {
            pendingFire ?: disk
        }
        fire?.let {
            events?.success(it)
            pendingFire = null
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
        // Match emitFromBackground: never deliver a synthetic retry over
        // an unacked real prayer (Dart ack would wipe the real pending).
        if (prayer == RESCHEDULE_RETRY_PRAYER && hasRealPendingFire(context)) {
            return
        }
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
            // Disk copy stays until acknowledgeAlarmFire.
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
        /** Match Dart DeliveryTiming.graceAfterAzan for overdue catch-up. */
        private const val OVERDUE_DELIVERY_GRACE_MS = 5 * 60 * 1000L
        private const val TAG = "ExactAlarmPlugin"
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

        /** Keep a live Activity for Settings intents (BAL-safe). */
        fun attachActivity(activity: Activity?) {
            instance?.attachActivity(activity)
        }

        /** Drop the live plugin when its FlutterEngine is destroyed. */
        fun detachInstance() {
            instance?.attachActivity(null)
            instance = null
            pendingFire = null
        }

        fun emitFromBackground(
            context: Context,
            prayer: String,
            scheduledEpochMs: Long,
            firedAtMs: Long,
            voiceId: String,
        ) {
            // Synthetic retry must not reach Dart (or overwrite in-memory
            // pendingFire) while a real unacked prayer is on disk —
            // acknowledgeAlarmFire would clear the real pending.
            if (prayer == RESCHEDULE_RETRY_PRAYER && hasRealPendingFire(context)) {
                return
            }
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
            // Never let a synthetic reschedule-retry erase an unacked real prayer.
            // Heal / retry fires would otherwise drop Maghrib (etc.) forever.
            if (prayer == RESCHEDULE_RETRY_PRAYER) {
                val existingPrayer = readPersistedPendingFire(context)
                    ?.get("prayer") as? String
                if (existingPrayer != null &&
                    existingPrayer.isNotEmpty() &&
                    existingPrayer != RESCHEDULE_RETRY_PRAYER
                ) {
                    return
                }
            }
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
         *
         * Operation is a foreground-service PendingIntent so the OS can
         * start [AdzanForegroundService] without a BroadcastReceiver hop
         * into a frozen cached process.
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

            val operation = fireServicePendingIntent(
                context,
                prayer = prayer,
                epochMs = epochMs,
                voiceId = voiceId,
            )

            val info = AlarmManager.AlarmClockInfo(epochMs, showIntent)
            alarmManager.setAlarmClock(info, operation)
            Log.i(TAG, "Armed AlarmClock for $prayer at $epochMs (FGS PendingIntent)")

            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PRAYER, prayer)
                .putLong(KEY_EPOCH, epochMs)
                .putString(KEY_VOICE_ID, voiceId)
                .apply()
            AlarmHealScheduler.enqueue(context)
            if (prayer != RESCHEDULE_RETRY_PRAYER) {
                NextPrayerWidget.refresh(context)
            }
        }

        @JvmStatic
        fun cancelAlarmClock(context: Context, clearPrefs: Boolean = true) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            // Cancel both the FGS operation and the legacy broadcast hop so
            // an in-flight Maghrib/Isha armed before the FGS migration is
            // not left orphaned when Dart re-arms.
            alarmManager.cancel(fireServicePendingIntent(context))
            alarmManager.cancel(legacyBroadcastPendingIntent(context))
            if (clearPrefs) {
                // Drop schedule keys only. A full clear() would wipe an
                // unacked pending fire (and apply() is async, so a later
                // persistPendingFire restore can still lose the race).
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .remove(KEY_PRAYER)
                    .remove(KEY_EPOCH)
                    .remove(KEY_VOICE_ID)
                    .apply()
                NextPrayerWidget.refresh(context)
            }
        }

        /** AlarmClock → FGS directly (preferred). */
        private fun fireServicePendingIntent(
            context: Context,
            prayer: String = "",
            epochMs: Long = 0L,
            voiceId: String = "",
        ): PendingIntent {
            val fireIntent = Intent(context, AdzanForegroundService::class.java).apply {
                action = AdzanForegroundService.ACTION_START
                if (prayer.isNotEmpty()) {
                    putExtra(EXTRA_PRAYER, prayer)
                    putExtra(EXTRA_SCHEDULED_EPOCH_MS, epochMs)
                    putExtra(EXTRA_VOICE_ID, voiceId)
                }
            }
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(
                    context,
                    REQ_FIRE,
                    fireIntent,
                    pendingFlags(),
                )
            } else {
                PendingIntent.getService(
                    context,
                    REQ_FIRE,
                    fireIntent,
                    pendingFlags(),
                )
            }
        }

        /** Pre-migration AlarmClock → [AdzanAlarmReceiver] broadcast. */
        private fun legacyBroadcastPendingIntent(context: Context): PendingIntent {
            val fireIntent = Intent(context, AdzanAlarmReceiver::class.java).apply {
                action = AdzanAlarmReceiver.ACTION_FIRE
            }
            return PendingIntent.getBroadcast(
                context,
                REQ_FIRE,
                fireIntent,
                pendingFlags(),
            )
        }

        /**
         * Same decision [BootReceiver] and [AlarmHealWorker] use.
         *
         * Unacked real pending fire → [replayPendingFireIfNeeded] only
         * (never [armRescheduleRetry], which would later emit a synthetic
         * fire whose [acknowledgeAlarmFire] clears the real pending).
         * Future persisted epoch → [rearmFromPrefsIfFuture].
         * Past epoch still within azan delivery grace → [fireOverduePrefsIfEligible]
         * (do not jump to reschedule-retry while Maghrib azan is still
         * upcoming — that skips the prayer after reboot/update).
         * Past grace or missing epoch → [armRescheduleRetry] (not a second
         * copy of that path).
         *
         * WorkManager is not immune to ColorOS Auto-launch / MIUI autostart
         * blocks. This shrinks the window when BOOT_COMPLETED never arrives;
         * it does not guarantee the next prayer fires.
         */
        @JvmStatic
        fun healPersistedWake(context: Context): Boolean {
            if (hasRealPendingFire(context)) {
                return replayPendingFireIfNeeded(context)
            }
            if (rearmFromPrefsIfFuture(context)) return true
            if (fireOverduePrefsIfEligible(context)) return true
            return armRescheduleRetry(context)
        }

        /** Unacked pending payload for a real prayer (not reschedule-retry). */
        @JvmStatic
        fun hasRealPendingFire(context: Context): Boolean {
            val pending = readPersistedPendingFire(context) ?: return false
            val prayer = pending["prayer"] as? String ?: return false
            return prayer.isNotEmpty() && prayer != RESCHEDULE_RETRY_PRAYER
        }

        /**
         * Re-start FGS + Dart for an unacked real prayer fire left on disk
         * after process death. Must run before [armRescheduleRetry], which
         * would otherwise [persistPendingFire] a `reschedule-retry` and
         * erase the real pending payload.
         *
         * Prefer a direct FGS start (BOOT_COMPLETED / alarm exemption).
         * If the OS blocks that (WorkManager hours later), fall back to
         * AlarmClock with the original wake extras — never a synthetic
         * retry name — so the receiver can start FGS the normal way.
         */
        @JvmStatic
        fun replayPendingFireIfNeeded(context: Context): Boolean {
            if (!hasRealPendingFire(context)) return false
            val pending = readPersistedPendingFire(context) ?: return false
            val prayer = pending["prayer"] as? String ?: return false
            val scheduledEpochMs =
                (pending["scheduledEpochMs"] as? Number)?.toLong() ?: return false
            if (scheduledEpochMs <= 0L) return false
            val firedAtMs =
                (pending["firedAtMs"] as? Number)?.toLong()
                    ?: System.currentTimeMillis()
            val voiceId = pending["voiceId"] as? String ?: ""
            val app = context.applicationContext
            try {
                val serviceIntent = Intent(app, AdzanForegroundService::class.java).apply {
                    action = AdzanForegroundService.ACTION_START
                    putExtra(EXTRA_PRAYER, prayer)
                    putExtra(EXTRA_SCHEDULED_EPOCH_MS, scheduledEpochMs)
                    putExtra(EXTRA_VOICE_ID, voiceId)
                    putExtra(AdzanAlarmReceiver.EXTRA_FIRED_AT_MS, firedAtMs)
                }
                ContextCompat.startForegroundService(app, serviceIntent)
                return true
            } catch (_: Exception) {
                return try {
                    armAlarmClock(app, scheduledEpochMs, prayer, voiceId)
                    true
                } catch (_: Exception) {
                    false
                }
            }
        }

        /**
         * Re-arm from persisted prefs if the wake epoch is still in the future.
         * Returns true when an alarm was armed.
         *
         * If the epoch already passed (device was off through the prayer, or
         * Dart never rescheduled), prefer [fireOverduePrefsIfEligible] when
         * azan is still within grace; otherwise [armRescheduleRetry] starts a
         * Dart reschedule without waiting for the user to open the app.
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
         * Wake epoch is already past, but azan (+ grace) has not — start FGS
         * for that prayer instead of [armRescheduleRetry].
         *
         * Wake is T−120. A reboot/update at wake+90s still has ~30s before
         * azan; jumping to reschedule-retry would skip Maghrib. Matches Dart
         * [DeliveryTiming.graceAfterAzan] (5 minutes after azan).
         */
        @JvmStatic
        fun fireOverduePrefsIfEligible(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val prayer = prefs.getString(KEY_PRAYER, null) ?: return false
            if (prayer.isEmpty() || prayer == RESCHEDULE_RETRY_PRAYER) return false
            if (!prefs.contains(KEY_EPOCH)) return false
            val epochMs = prefs.getLong(KEY_EPOCH, 0L)
            if (epochMs <= 0L) return false
            val now = System.currentTimeMillis()
            if (epochMs > now) return false
            // wake = azan − 120s ⇒ azan = wake + 120s
            val azanEpochMs = epochMs + 120_000L
            if (now > azanEpochMs + OVERDUE_DELIVERY_GRACE_MS) return false
            val voiceId = prefs.getString(KEY_VOICE_ID, null) ?: ""
            val app = context.applicationContext
            try {
                val serviceIntent = Intent(app, AdzanForegroundService::class.java).apply {
                    action = AdzanForegroundService.ACTION_START
                    putExtra(EXTRA_PRAYER, prayer)
                    putExtra(EXTRA_SCHEDULED_EPOCH_MS, epochMs)
                    putExtra(EXTRA_VOICE_ID, voiceId)
                    putExtra(AdzanAlarmReceiver.EXTRA_FIRED_AT_MS, now)
                }
                ContextCompat.startForegroundService(app, serviceIntent)
                return true
            } catch (_: Exception) {
                return try {
                    // Past epoch → AlarmManager fires immediately via receiver.
                    armAlarmClock(app, epochMs, prayer, voiceId)
                    true
                } catch (_: Exception) {
                    false
                }
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
        @JvmOverloads
        fun requestExactAlarmPermission(
            context: Context,
            activity: Activity? = instance?.hostActivity(),
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            val host = activity ?: instance?.hostActivity()
            val packaged = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${context.packageName}")
            }
            val bare = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
            // Prefer live Activity (Android 14+ BAL blocks app-context starts).
            for (intent in listOf(packaged, bare, details)) {
                try {
                    startSettings(host, context, intent)
                    return
                } catch (_: Exception) {
                    // try next candidate
                }
            }
        }

        private fun startSettings(
            activity: Activity?,
            context: Context,
            intent: Intent,
        ) {
            if (activity != null && !activity.isFinishing && !activity.isDestroyed) {
                activity.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
        }

        private fun pendingFlags(): Int {
            return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }
    }
}
