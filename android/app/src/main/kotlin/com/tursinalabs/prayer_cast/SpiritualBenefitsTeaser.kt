package com.tursinalabs.prayer_cast

import android.content.Context
import java.io.File
import java.util.Locale

/**
 * Compact shade teasers for the T−120 FGS notification.
 *
 * Built in Kotlin before Dart runs. Keys are canonical prayers
 * (`fajr` / `dhuhr` / `asr` / `maghrib` / `isha`). A `-dryrun`
 * suffix is stripped for lookup and never shown raw.
 *
 * Locale: `app_flutter/app_locale.txt` when the user picked EN/ID,
 * else system language with the same default-to-id rule as Dart.
 */
object SpiritualBenefitsTeaser {
    private const val DRY_RUN_SUFFIX = "-dryrun"

    data class Copy(
        val name: String,
        val teaser: String,
        val lines: List<String>,
        val dryRunLabel: String,
    )

    private val en = mapOf(
        "fajr" to Copy(
            name = "Fajr",
            teaser = "Spiritual awakening and consciousness",
            lines = listOf(
                "Blessed time for remembrance and reflection",
                "Protection throughout the day",
                "Spiritual awakening and consciousness",
            ),
            dryRunLabel = "dry-run",
        ),
        "dhuhr" to Copy(
            name = "Dhuhr",
            teaser = "Midday spiritual recharge",
            lines = listOf(
                "Break from worldly activities",
                "Midday spiritual recharge",
                "Connection with the community",
            ),
            dryRunLabel = "dry-run",
        ),
        "asr" to Copy(
            name = "Asr",
            teaser = "Protection from afternoon negligence",
            lines = listOf(
                "Protection from afternoon negligence",
                "Preparation for evening",
                "Strengthening of faith",
            ),
            dryRunLabel = "dry-run",
        ),
        "maghrib" to Copy(
            name = "Maghrib",
            teaser = "Gratitude for the day's blessings",
            lines = listOf(
                "Gratitude for the day's blessings",
                "Family gathering time",
                "Breaking of the fast (if fasting)",
            ),
            dryRunLabel = "dry-run",
        ),
        "isha" to Copy(
            name = "Isha",
            teaser = "Peaceful end to the day",
            lines = listOf(
                "Completion of daily prayers",
                "Peaceful end to the day",
                "Preparation for rest",
            ),
            dryRunLabel = "dry-run",
        ),
    )

    private val id = mapOf(
        "fajr" to Copy(
            name = "Subuh",
            teaser = "Kebangkitan dan kesadaran spiritual",
            lines = listOf(
                "Waktu penuh berkah untuk zikir dan perenungan",
                "Perlindungan sepanjang hari",
                "Kebangkitan dan kesadaran spiritual",
            ),
            dryRunLabel = "uji coba",
        ),
        "dhuhr" to Copy(
            name = "Dzuhur",
            teaser = "Isi ulang spiritual di tengah hari",
            lines = listOf(
                "Jeda dari kesibukan duniawi",
                "Isi ulang spiritual di tengah hari",
                "Terhubung dengan komunitas",
            ),
            dryRunLabel = "uji coba",
        ),
        "asr" to Copy(
            name = "Asar",
            teaser = "Perlindungan dari kelalaian sore hari",
            lines = listOf(
                "Perlindungan dari kelalaian sore hari",
                "Persiapan menyambut petang",
                "Penguatan iman",
            ),
            dryRunLabel = "uji coba",
        ),
        "maghrib" to Copy(
            name = "Maghrib",
            teaser = "Syukur atas nikmat hari ini",
            lines = listOf(
                "Syukur atas nikmat hari ini",
                "Waktu berkumpul bersama keluarga",
                "Berbuka puasa (jika berpuasa)",
            ),
            dryRunLabel = "uji coba",
        ),
        "isha" to Copy(
            name = "Isya",
            teaser = "Penutup hari yang damai",
            lines = listOf(
                "Penyelesaian sholat harian",
                "Penutup hari yang damai",
                "Persiapan untuk istirahat",
            ),
            dryRunLabel = "uji coba",
        ),
    )

    fun canonicalPrayer(prayer: String): String {
        return if (prayer.endsWith(DRY_RUN_SUFFIX)) {
            prayer.substring(0, prayer.length - DRY_RUN_SUFFIX.length)
        } else {
            prayer
        }
    }

    fun isDryRun(prayer: String): Boolean = prayer.endsWith(DRY_RUN_SUFFIX)

    fun shadeLanguage(context: Context): String {
        return try {
            val file = File(context.applicationInfo.dataDir, "app_flutter/app_locale.txt")
            if (file.exists()) {
                val code = file.readText().trim()
                if (code == "en" || code == "id") return code
            }
            if (Locale.getDefault().language == "en") "en" else "id"
        } catch (_: Exception) {
            "en"
        }
    }

    fun preparingTitle(language: String = "en"): String {
        return if (language == "id") "Menyiapkan adzan" else "Preparing adzan"
    }

    fun playingTitle(language: String = "en"): String {
        return if (language == "id") "Memutar adzan" else "Playing adhan"
    }

    fun stopLabel(language: String = "en"): String {
        return if (language == "id") "Berhenti" else "Stop"
    }

    fun contentTitle(prayer: String, language: String = "en"): String {
        return preparingTitle(language)
    }

    fun contentText(prayer: String, language: String = "en"): String {
        val copy = copyFor(prayer, language)
        if (copy == null) {
            return if (isDryRun(prayer)) "Adhan (dry-run)" else "Adhan"
        }
        val label = if (isDryRun(prayer)) {
            "${copy.name} (${copy.dryRunLabel})"
        } else {
            copy.name
        }
        return "$label · ${copy.teaser}"
    }

    fun bigText(prayer: String, language: String = "en"): String {
        val copy = copyFor(prayer, language) ?: return contentText(prayer, language)
        return copy.lines.take(3).joinToString("\n")
    }

    private fun copyFor(prayer: String, language: String): Copy? {
        val table = if (language == "id") id else en
        return table[canonicalPrayer(prayer)]
    }
}
