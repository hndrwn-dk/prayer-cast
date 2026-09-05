package com.tursinalabs.prayer_cast

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContentView (super.onCreate). Required for pre-Android 15
        // parity; Android 15+ (targetSdk 35+) enforces edge-to-edge anyway.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
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
        // Only reuse the FGS engine after Dart marked delivery ready.
        // A hung boot (splash forever) must not be reused — discard it so
        // a fresh engine can still play the persisted pending fire.
        return PrayerCastFlutter.engineForActivity()
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        // Keep a ready shared delivery engine alive when leaving the UI.
        return !PrayerCastFlutter.isDeliveryReady()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Always bind: a cached FGS engine would otherwise skip this channel.
        LaunchPrayerPlugin.bind(flutterEngine, this)
        ShareTextPlugin.bind(flutterEngine, this)
        if (PrayerCastFlutter.cached() === flutterEngine) {
            return
        }
        PrayerCastFlutter.registerAppPlugins(flutterEngine, applicationContext)
        PrayerCastFlutter.cacheIfAbsent(flutterEngine)
    }
}
