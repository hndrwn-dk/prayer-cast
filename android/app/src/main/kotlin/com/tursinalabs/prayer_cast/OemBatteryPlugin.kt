package com.tursinalabs.prayer_cast

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Opens OEM battery-optimisation and autostart settings (spec §6.3).
 *
 * Battery (`open`) prefers a package-scoped screen so the user does not
 * search an all-apps list. Stock Android: system
 * [Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS] dialog for this
 * package, then App info. OEM list intents stay for restrictive brands.
 *
 * Autostart (`openAutostartSettings`) is separate — ColorOS Auto-launch
 * can drop BOOT_COMPLETED even when battery optimisation is unrestricted.
 *
 * OEM component names are version-fragile and not official. None of the
 * autostart activities below were verified on a physical Oppo / Realme /
 * Xiaomi / Vivo in this change — they are community-documented candidates.
 * [tryStart] walks the list; a missing activity just falls through.
 */
class OemBatteryPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    private var activityRef: WeakReference<Activity>? = null

    fun attachActivity(activity: Activity?) {
        activityRef = activity?.let { WeakReference(it) }
    }

    private fun hostActivity(): Activity? = activityRef?.get()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canOpen" -> result.success(true)
            "open" -> result.success(openBatterySettings())
            "openAutostartSettings" -> result.success(openAutostartSettings())
            "isRestrictiveOem" -> result.success(isRestrictiveOem())
            "isBatteryUnrestricted" -> result.success(isBatteryUnrestricted())
            else -> result.notImplemented()
        }
    }

    private fun openBatterySettings(): Boolean {
        val pkg = context.packageName
        val candidates = mutableListOf<Intent>()

        // Stock / Pixel: system Allow dialog for THIS app (no search list).
        // Never fall through to ACTION_SETTINGS (Settings home) — that looks
        // like a broken handoff.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !isBatteryUnrestricted()
        ) {
            candidates += Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            ).apply {
                data = Uri.parse("package:$pkg")
            }
        }

        // Restrictive OEMs when present (brand-specific battery UI).
        candidates += batteryOemIntents()

        // App info for this package — Battery / Unrestricted is one tap.
        candidates += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$pkg")
        }

        // All-apps battery list only as last package-scoped fallback.
        candidates += Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

        return tryStart(candidates)
    }

    private fun openAutostartSettings(): Boolean {
        val candidates = autostartOemIntents() + listOf(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            },
            Intent(Settings.ACTION_SETTINGS),
        )
        return tryStart(candidates)
    }

    /**
     * Battery / background-restriction screens only. Autostart lives in
     * [autostartOemIntents] so the UI can prompt for each separately.
     */
    private fun batteryOemIntents(): List<Intent> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = mutableListOf<Intent>()
        when {
            manufacturer.contains("xiaomi") ||
                manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> {
                intents += componentIntent(
                    "com.miui.powerkeeper",
                    "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
                )
            }
            manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") -> {
                intents += componentIntent(
                    "com.oplus.battery",
                    "com.oplus.battery.ui.BatteryAppListActivity",
                )
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                intents += componentIntent(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                )
            }
            manufacturer.contains("samsung") -> {
                intents += componentIntent(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                )
                intents += componentIntent(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                )
            }
        }
        return intents
    }

    /**
     * Auto-launch / Startup Manager. Best-effort community names.
     *
     * NONE of these OEM activities were opened on a physical Oppo / Realme /
     * Xiaomi / Vivo in this change. [tryStart] must keep walking on
     * ActivityNotFound / SecurityException (OPPO_COMPONENT_SAFE).
     */
    private fun autostartOemIntents(): List<Intent> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = mutableListOf<Intent>()
        when {
            manufacturer.contains("xiaomi") ||
                manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> {
                intents += componentIntent(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                )
                intents += Intent("miui.intent.action.OP_AUTO_START")
                    .addCategory(Intent.CATEGORY_DEFAULT)
            }
            manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") -> {
                intents += colorOsSettingsAppInfoIntent()
                intents += componentIntent(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.permission.startup.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.startupapp.view.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.startupapp.StartupAppListActivity",
                )
                intents += Intent("com.coloros.safecenter.startupapp.permission.STARTUP_APP_LIST")
                    .setPackage("com.coloros.safecenter")
                intents += Intent("com.coloros.safecenter.startupapp.permission.STARTUP_APP_LIST")
                    .setPackage("com.oplus.safecenter")
                intents += componentIntent(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.view.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                )
                intents += componentIntent(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                )
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                intents += componentIntent(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                )
                intents += componentIntent(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                )
            }
        }
        return intents
    }

    /** ColorOS 6+: App info hosts "Allow Auto Start-up" (dontkillmyapp Oppo). */
    private fun colorOsSettingsAppInfoIntent(): Intent {
        return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            setPackage("com.android.settings")
            addCategory(Intent.CATEGORY_DEFAULT)
        }
    }

    private fun tryStart(intents: List<Intent>): Boolean {
        val activity = hostActivity()
        for (intent in intents) {
            try {
                if (activity != null && !activity.isFinishing && !activity.isDestroyed) {
                    activity.startActivity(intent)
                } else {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
                return true
            } catch (_: Exception) {
                // Wrong or removed OEM component — try the next candidate.
            }
        }
        return false
    }

    private fun isRestrictiveOem(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return RESTRICTIVE_MARKERS.any { manufacturer.contains(it) }
    }

    /** True when the app is exempt from Doze / app-standby battery limits. */
    private fun isBatteryUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(PowerManager::class.java) ?: return true
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun componentIntent(pkg: String, cls: String): Intent {
        return Intent().setComponent(ComponentName(pkg, cls))
    }

    companion object {
        const val CHANNEL = "prayer_cast/oem_battery"

        private val RESTRICTIVE_MARKERS = listOf(
            "oppo",
            "realme",
            "oneplus",
            "xiaomi",
            "redmi",
            "poco",
            "vivo",
            "iqoo",
        )

        @Volatile
        private var instance: OemBatteryPlugin? = null

        fun attachActivity(activity: Activity?) {
            instance?.attachActivity(activity)
        }

        fun detachInstance() {
            instance?.attachActivity(null)
            instance = null
        }

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val plugin = OemBatteryPlugin(context.applicationContext)
            instance = plugin
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).setMethodCallHandler(plugin)
        }
    }
}
