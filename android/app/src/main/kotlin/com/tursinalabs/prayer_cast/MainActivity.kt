package com.tursinalabs.prayer_cast

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContentView (super.onCreate). Not androidx
        // enableEdgeToEdge(): its EdgeToEdgeApi23/26/29 paths call
        // Window.setStatusBarColor / setNavigationBarColor, which Play
        // Console flags as deprecated on Android 15+. Transparent bars come
        // from the theme instead, so no deprecated setter reaches the dex.
        WindowCompat.setDecorFitsSystemWindows(window, false)
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

    override fun onDestroy() {
        // Before super, so the hang restart is posted after Flutter detaches
        // the view. Destroying the engine while the view is still in layout
        // is the setViewportMetrics crash.
        PrayerCastFlutter.onUiDetached(applicationContext)
        super.onDestroy()
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        // Cancel the headless hang restart before it can destroy an engine
        // this activity is about to attach a FlutterView to.
        PrayerCastFlutter.onUiAttached()
        return PrayerCastFlutter.engineForActivity()
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        // Never. Flutter only evicts a destroyed engine from
        // FlutterEngineCache when getCachedEngineId() is set. We cache via
        // provideFlutterEngine, so a host destroy leaves a detached engine.
        // The next notification tap then crashes in setViewportMetrics and
        // the adhan waits for a new process.
        return DeliveryEnginePolicy.destroyEngineWithHost()
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
