package com.tursinalabs.prayer_cast

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        LaunchPrayerPlugin.notifyNewIntent(intent)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return PrayerCastFlutter.cached()
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return PrayerCastFlutter.cached() == null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Always bind: a cached FGS engine would otherwise skip this channel.
        LaunchPrayerPlugin.bind(flutterEngine, this)
        if (PrayerCastFlutter.cached() === flutterEngine) {
            return
        }
        PrayerCastFlutter.registerAppPlugins(flutterEngine, applicationContext)
        PrayerCastFlutter.cacheIfAbsent(flutterEngine)
    }
}
