package com.tursinalabs.prayer_cast

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Optional travel refresh: sample last-known coarse location while the
 * device is already doing background work. If the phone moved ~25 km,
 * arm a short Dart reschedule so prayer city/times update.
 */
class TravelRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        TravelLocationStore.maybeRequestReschedule(applicationContext)
        return Result.success()
    }
}

object TravelLocationStore {
    const val PREFS = "travel_location"
    const val KEY_ENABLED = "enabled"
    const val KEY_LAT = "lat"
    const val KEY_LNG = "lng"
    private const val TAG = "TravelLocation"
    private const val UNIQUE_WORK = "prayer_cast_travel_refresh"
    private const val MOVE_METERS = 25_000.0

    fun sync(context: Context, enabled: Boolean, latitude: Double?, longitude: Double?) {
        val app = context.applicationContext
        val editor = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, enabled)
        if (latitude != null && longitude != null) {
            editor.putString(KEY_LAT, latitude.toString())
            editor.putString(KEY_LNG, longitude.toString())
        }
        editor.apply()
        if (enabled) {
            enqueue(app)
        } else {
            try {
                WorkManager.getInstance(app).cancelUniqueWork(UNIQUE_WORK)
            } catch (e: Exception) {
                Log.w(TAG, "cancel travel work failed", e)
            }
        }
    }

    fun maybeRequestReschedule(context: Context) {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        if (!hasLocationPermission(app)) return
        val savedLat = prefs.getString(KEY_LAT, null)?.toDoubleOrNull() ?: return
        val savedLng = prefs.getString(KEY_LNG, null)?.toDoubleOrNull() ?: return
        val current = lastKnown(app) ?: return
        val distance = haversineMeters(savedLat, savedLng, current.latitude, current.longitude)
        if (distance < MOVE_METERS) return
        Log.i(TAG, "Moved ${distance.toInt()}m — requesting Dart reschedule")
        ExactAlarmPlugin.armRescheduleRetry(app)
    }

    private fun enqueue(context: Context) {
        try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(false)
                .build()
            val request = PeriodicWorkRequestBuilder<TravelRefreshWorker>(
                6,
                TimeUnit.HOURS,
            )
                .setConstraints(constraints)
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    UNIQUE_WORK,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request,
                )
        } catch (e: Exception) {
            Log.w(TAG, "enqueue travel work failed", e)
        }
    }

    private fun hasLocationPermission(context: Context): Boolean {
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!coarse) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun lastKnown(context: Context): Location? {
        val manager = context.getSystemService(LocationManager::class.java) ?: return null
        val providers = listOf(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
            LocationManager.GPS_PROVIDER,
        )
        var best: Location? = null
        for (provider in providers) {
            if (!manager.isProviderEnabled(provider)) continue
            val sample = try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } catch (_: Exception) {
                null
            } ?: continue
            if (best == null || sample.time > best.time) {
                best = sample
            }
        }
        return best
    }

    private fun haversineMeters(
        lat1: Double,
        lng1: Double,
        lat2: Double,
        lng2: Double,
    ): Double {
        val earth = 6_371_000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLng / 2) * sin(dLng / 2)
        return 2 * earth * atan2(sqrt(a), sqrt(1 - a))
    }
}
