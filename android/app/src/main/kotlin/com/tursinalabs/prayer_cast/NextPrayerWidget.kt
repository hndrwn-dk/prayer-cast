package com.tursinalabs.prayer_cast

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale
import java.util.concurrent.TimeUnit

/** Home-screen next-prayer card. Reads the same prefs [ExactAlarmPlugin] arms. */
class NextPrayerWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context.applicationContext))
        }
    }

    companion object {
        fun refresh(context: Context) {
            val app = context.applicationContext
            val manager = AppWidgetManager.getInstance(app)
            val ids = manager.getAppWidgetIds(ComponentName(app, NextPrayerWidget::class.java))
            if (ids.isEmpty()) return
            val views = buildViews(app)
            for (id in ids) {
                manager.updateAppWidget(id, views)
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.next_prayer_widget)
            val launch = PendingIntent.getActivity(
                context,
                40,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.next_prayer_widget_root, launch)

            val prefs = context.getSharedPreferences(ExactAlarmPlugin.PREFS, Context.MODE_PRIVATE)
            val prayer = prefs.getString(ExactAlarmPlugin.KEY_PRAYER, null)
            val epochMs = if (prefs.contains(ExactAlarmPlugin.KEY_EPOCH)) {
                prefs.getLong(ExactAlarmPlugin.KEY_EPOCH, 0L)
            } else {
                0L
            }
            val empty = prayer.isNullOrEmpty() ||
                epochMs <= 0L ||
                prayer == ExactAlarmPlugin.RESCHEDULE_RETRY_PRAYER
            if (empty) {
                views.setTextViewText(
                    R.id.next_prayer_name,
                    context.getString(R.string.next_prayer_widget_empty),
                )
                views.setTextViewText(R.id.next_prayer_time, "")
                views.setTextViewText(R.id.next_prayer_countdown, "")
                return views
            }

            views.setTextViewText(R.id.next_prayer_name, prayerLabel(context, prayer))
            views.setTextViewText(R.id.next_prayer_time, formatClock(epochMs))
            views.setTextViewText(
                R.id.next_prayer_countdown,
                remainingLabel(context, epochMs),
            )
            return views
        }

        private fun prayerLabel(context: Context, key: String): String {
            val id = when (key.lowercase(Locale.US)) {
                "fajr" -> R.string.prayer_name_fajr
                "dhuhr" -> R.string.prayer_name_dhuhr
                "asr" -> R.string.prayer_name_asr
                "maghrib" -> R.string.prayer_name_maghrib
                "isha" -> R.string.prayer_name_isha
                else -> 0
            }
            return if (id == 0) key else context.getString(id)
        }

        private fun formatClock(epochMs: Long): String {
            val cal = java.util.Calendar.getInstance()
            cal.timeInMillis = epochMs
            val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
            val minute = cal.get(java.util.Calendar.MINUTE)
            return String.format(Locale.getDefault(), "%02d:%02d", hour, minute)
        }

        private fun remainingLabel(context: Context, epochMs: Long): String {
            val delta = epochMs - System.currentTimeMillis()
            if (delta <= 0L) return context.getString(R.string.next_prayer_widget_now)
            val totalMin = TimeUnit.MILLISECONDS.toMinutes(delta)
            val hours = totalMin / 60
            val minutes = totalMin % 60
            val clock = if (hours > 0) {
                String.format(Locale.getDefault(), "%d:%02d", hours, minutes)
            } else {
                String.format(Locale.getDefault(), "0:%02d", minutes)
            }
            return context.getString(R.string.next_prayer_widget_in, clock)
        }
    }
}
