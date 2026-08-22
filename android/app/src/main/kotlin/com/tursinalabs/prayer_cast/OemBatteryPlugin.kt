package com.tursinalabs.prayer_cast

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Opens OEM battery-optimisation and autostart settings (spec §6.3).
 *
 * Battery (`open`) and autostart (`openAutostartSettings`) are separate
 * screens. ColorOS Auto-launch can drop BOOT_COMPLETED even when battery
 * optimisation is already unrestricted.
 *
 * OEM component names are version-fragile and not official. None of the
 * autostart activities below were verified on a physical Oppo / Realme /
 * Xiaomi / Vivo in this change — they are community-documented candidates.
 * [tryStart] walks the list; a missing activity just falls through.
 *
 * Manual QA (required before trusting production copy that names a brand):
 * on each OEM, tap the in-app "Open auto-launch settings" button and
 * confirm the Auto-launch / Startup Manager screen actually opens.
 */
class OemBatteryPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canOpen" -> result.success(true)
            "open" -> result.success(openBatterySettings())
            "openAutostartSettings" -> result.success(openAutostartSettings())
            "isRestrictiveOem" -> result.success(isRestrictiveOem())
            else -> result.notImplemented()
        }
    }

    private fun openBatterySettings(): Boolean {
        val candidates = batteryOemIntents() + listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS).takeIf {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            },
            Intent(Settings.ACTION_SETTINGS),
        ).filterNotNull()
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
     * Auto-launch / Startup Manager. Best-effort community names:
     *
     * ColorOS current (Oppo/Realme/OnePlus, NOT device-verified here):
     *   com.oplus.safecenter StartupAppList activities; implicit
     *   STARTUP_APP_LIST action; com.android.settings as last OEM try.
     * ColorOS older (pre-12, already used in this plugin historically):
     *   com.coloros.safecenter / com.oppo.safe StartupAppList activities.
     * MIUI (community-documented; already shipped in this plugin):
     *   com.miui.securitycenter AutoStartManagementActivity.
     * Vivo (community-documented; already shipped in this plugin):
     *   com.vivo.permissionmanager BgStartUpManagerActivity,
     *   com.iqoo.secure BgStartUpManager.
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
            }
            manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") -> {
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

    private fun tryStart(intents: List<Intent>): Boolean {
        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
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

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).setMethodCallHandler(OemBatteryPlugin(context.applicationContext))
        }
    }
}
