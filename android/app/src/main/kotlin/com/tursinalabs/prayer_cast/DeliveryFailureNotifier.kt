package com.tursinalabs.prayer_cast

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/** Posts a one-shot notification when Cast delivery fails at azan time. */
object DeliveryFailureNotifier {
    private const val CHANNEL_ID = "cast_delivery_failure"
    private const val NOTIFICATION_ID = 2003

    fun show(context: Context, title: String, body: String) {
        val app = context.applicationContext
        ensureChannel(app)
        val launch = PendingIntent.getActivity(
            app,
            0,
            Intent(app, MainActivity::class.java),
            pendingFlags(),
        )
        val notification = NotificationCompat.Builder(app, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
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

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Cast delivery failures",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "When adzan could not play on the home speaker"
        }
        manager.createNotificationChannel(channel)
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
