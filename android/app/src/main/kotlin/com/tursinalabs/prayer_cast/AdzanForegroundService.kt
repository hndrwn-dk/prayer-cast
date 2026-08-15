package com.tursinalabs.prayer_cast

import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service (type specialUse) holding PARTIAL_WAKE_LOCK and
 * WifiLock(WIFI_MODE_FULL_HIGH_PERF) for the delivery window (spec §5.5).
 *
 * Play-honest type: this service does not play audio. It holds CPU/Wi-Fi
 * locks and launches [MainActivity] so Dart can Cast adhan to the home
 * speaker, or play beep / phone adhan via audioplayers. mediaPlayback
 * would be a type mismatch (Play takedown). Cast SDK
 * MediaNotificationService stays mediaPlayback.
 *
 * WHY locks: Without the high-perf Wi-Fi lock, mDNS discovery fails
 * intermittently when the screen is off — the number one cause of
 * "works when holding the phone, fails overnight".
 *
 * Dart delivery runs in a cached [FlutterEngine] started from this
 * service. On API 34+ a raw [startActivity] from this FGS is BAL-blocked
 * (Pixel same-UID PendingIntent → BAL_BLOCK), so waiting for [MainActivity]
 * misses azan and replays when the user later opens the app.
 * Still try full-screen intent + PendingIntent BAL opt-in for lockscreen UX.
 * specialUse is API 34+; older platforms startForeground without a type.
 */
class AdzanForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val stopAfterWindow = Runnable {
        Log.w(TAG, "Delivery window elapsed without Dart stop — stopping FGS")
        releaseLocks()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            timeoutHandler.removeCallbacks(stopAfterWindow)
            releaseLocks()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val prayer = intent?.getStringExtra(ExactAlarmPlugin.EXTRA_PRAYER) ?: "adzan"
        val scheduledEpochMs =
            intent?.getLongExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, 0L) ?: 0L
        val voiceId = intent?.getStringExtra(ExactAlarmPlugin.EXTRA_VOICE_ID) ?: ""
        val firedAtMs =
            intent?.getLongExtra(AdzanAlarmReceiver.EXTRA_FIRED_AT_MS, System.currentTimeMillis())
                ?: System.currentTimeMillis()

        ensureChannel()
        val launchPi = deliveryActivityPendingIntent(
            prayer = prayer,
            scheduledEpochMs = scheduledEpochMs,
            voiceId = voiceId,
            firedAtMs = firedAtMs,
        )
        val notification = buildNotification(prayer, launchPi)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        acquireLocks()
        timeoutHandler.removeCallbacks(stopAfterWindow)
        timeoutHandler.postDelayed(stopAfterWindow, DELIVERY_WINDOW_MS)

        if (scheduledEpochMs > 0L) {
            ExactAlarmPlugin.emitFromBackground(
                this,
                prayer,
                scheduledEpochMs,
                firedAtMs,
                voiceId,
            )
        }

        // Full-screen intent covers lockscreen / screen-off. PendingIntent.send
        // with creator + sender BAL opt-in is still blocked on Pixel / API 36
        // when sender and creator share a UID (sameUid → BAL_BLOCK). Dart
        // therefore starts in this process via [PrayerCastFlutter.ensureStarted].
        try {
            val sendOpts = ActivityOptions.makeBasic()
            applyBalSenderMode(sendOpts)
            launchPi.send(this, 0, null, null, null, null, sendOpts.toBundle())
        } catch (e: PendingIntent.CanceledException) {
            Log.w(TAG, "delivery activity PendingIntent canceled; startActivity fallback", e)
            startActivity(deliveryActivityIntent(prayer, scheduledEpochMs, voiceId, firedAtMs))
        }

        try {
            PrayerCastFlutter.ensureStarted(this)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start FlutterEngine for adzan delivery", e)
        }

        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        timeoutHandler.removeCallbacks(stopAfterWindow)
        releaseLocks()
        super.onDestroy()
    }

    private fun acquireLocks() {
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "prayer_cast:adzan_wake",
        )?.also {
            it.setReferenceCounted(false)
            it.acquire(10 * 60 * 1000L)
        }

        @Suppress("DEPRECATION")
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        wifiLock = wifi.createWifiLock(
            WifiManager.WIFI_MODE_FULL_HIGH_PERF,
            "prayer_cast:adzan_wifi",
        ).also {
            it.setReferenceCounted(false)
            it.acquire()
        }
    }

    private fun releaseLocks() {
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: RuntimeException) {
        }
        wifiLock = null
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: RuntimeException) {
        }
        wakeLock = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Adzan delivery",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Keeps the device awake while preparing adzan cast"
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun deliveryActivityIntent(
        prayer: String,
        scheduledEpochMs: Long,
        voiceId: String,
        firedAtMs: Long,
    ): Intent {
        return Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra("alarm_fired", true)
            putExtra(ExactAlarmPlugin.EXTRA_PRAYER, prayer)
            putExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, scheduledEpochMs)
            putExtra(ExactAlarmPlugin.EXTRA_VOICE_ID, voiceId)
            putExtra(AdzanAlarmReceiver.EXTRA_FIRED_AT_MS, firedAtMs)
        }
    }

    private fun deliveryActivityPendingIntent(
        prayer: String,
        scheduledEpochMs: Long,
        voiceId: String,
        firedAtMs: Long,
    ): PendingIntent {
        val launch = deliveryActivityIntent(prayer, scheduledEpochMs, voiceId, firedAtMs)
        val options = ActivityOptions.makeBasic()
        applyBalCreatorMode(options)
        return PendingIntent.getActivity(
            this,
            REQ_LAUNCH,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            options.toBundle(),
        )
    }

    private fun buildNotification(prayer: String, fullScreen: PendingIntent): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Menyiapkan adzan")
            .setContentText(prayer)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentIntent(fullScreen)
            .setFullScreenIntent(fullScreen, true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setOngoing(true)
            .build()
    }

    private fun applyBalCreatorMode(options: ActivityOptions) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        }
    }

    private fun applyBalSenderMode(options: ActivityOptions) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            options.setPendingIntentBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            options.setPendingIntentBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        }
    }

    companion object {
        const val ACTION_START = "com.tursinalabs.prayer_cast.ACTION_START_FGS"
        const val ACTION_STOP = "com.tursinalabs.prayer_cast.ACTION_STOP_FGS"
        private const val TAG = "AdzanForegroundService"
        private const val CHANNEL_ID = "adzan_delivery_alarm"
        private const val NOTIFICATION_ID = 42
        private const val REQ_LAUNCH = 1003
        private const val DELIVERY_WINDOW_MS = 10 * 60 * 1000L
    }
}
