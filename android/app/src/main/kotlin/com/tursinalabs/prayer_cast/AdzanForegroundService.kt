package com.tursinalabs.prayer_cast

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
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service (type mediaPlayback) holding PARTIAL_WAKE_LOCK and
 * WifiLock(WIFI_MODE_FULL_HIGH_PERF) for the delivery window (spec §5.5).
 *
 * WHY: Without the high-perf Wi-Fi lock, mDNS discovery fails intermittently
 * when the screen is off — the number one cause of "works when holding the
 * phone, fails overnight".
 */
class AdzanForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
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
        val notification = buildNotification(prayer)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        acquireLocks()

        ExactAlarmPlugin.emitFromBackground(prayer, scheduledEpochMs, firedAtMs, voiceId)

        // Bring UI/engine up so Dart can run the delivery orchestrator.
        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("alarm_fired", true)
            putExtra(ExactAlarmPlugin.EXTRA_PRAYER, prayer)
            putExtra(ExactAlarmPlugin.EXTRA_SCHEDULED_EPOCH_MS, scheduledEpochMs)
            putExtra(ExactAlarmPlugin.EXTRA_VOICE_ID, voiceId)
            putExtra(AdzanAlarmReceiver.EXTRA_FIRED_AT_MS, firedAtMs)
        }
        startActivity(launch)

        return START_STICKY
    }

    override fun onDestroy() {
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
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the device awake while preparing adzan cast"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(prayer: String): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Menyiapkan adzan")
            .setContentText(prayer)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .build()
    }

    companion object {
        const val ACTION_START = "com.tursinalabs.prayer_cast.ACTION_START_FGS"
        const val ACTION_STOP = "com.tursinalabs.prayer_cast.ACTION_STOP_FGS"
        private const val CHANNEL_ID = "adzan_delivery"
        private const val NOTIFICATION_ID = 42
    }
}
