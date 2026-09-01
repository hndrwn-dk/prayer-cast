package com.tursinalabs.prayer_cast

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.util.Log

/**
 * Alarm-stream beep for [PrayerDeliveryMode.beep]. Flutter audioplayers
 * uses the media stream and is silent when the screen is off / DND.
 */
object LocalAlarmSound {
    private const val TAG = "LocalAlarmSound"
    private const val REPEAT_COUNT = 3
    private const val GAP_MS = 180L

    fun playBeep(context: Context) {
        if (playRaw(context.applicationContext, R.raw.beep, REPEAT_COUNT)) return
        playToneFallback()
    }

    fun playTakbir(context: Context) {
        if (playRaw(context.applicationContext, R.raw.takbir, 1)) return
        playToneFallback()
    }

    private fun playRaw(context: Context, rawId: Int, repeats: Int): Boolean {
        var played = false
        try {
            repeat(repeats) { index ->
                val player = MediaPlayer()
                val afd = context.resources.openRawResourceFd(rawId)
                try {
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                } finally {
                    afd.close()
                }
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_ALARM)
                        .build(),
                )
                player.setVolume(1f, 1f)
                player.prepare()
                val done = Object()
                var finished = false
                player.setOnCompletionListener {
                    synchronized(done) {
                        finished = true
                        done.notifyAll()
                    }
                }
                player.setOnErrorListener { _, what, extra ->
                    Log.w(TAG, "beep MediaPlayer error what=$what extra=$extra")
                    synchronized(done) {
                        finished = true
                        done.notifyAll()
                    }
                    true
                }
                player.start()
                played = true
                synchronized(done) {
                    if (!finished) {
                        done.wait(4_000L)
                    }
                }
                try {
                    player.stop()
                } catch (_: Exception) {
                }
                player.release()
                if (index < repeats - 1) {
                    Thread.sleep(GAP_MS)
                }
            }
            return played
        } catch (e: Exception) {
            Log.w(TAG, "raw asset failed", e)
            if (rawId == R.raw.beep) playToneFallback()
            return played
        }
    }

    private fun playToneFallback() {
        try {
            val tone = ToneGenerator(AudioManager.STREAM_ALARM, 100)
            try {
                repeat(REPEAT_COUNT) { index ->
                    tone.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 350)
                    Thread.sleep(500)
                    if (index < REPEAT_COUNT - 1) {
                        Thread.sleep(GAP_MS)
                    }
                }
            } finally {
                tone.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "beep tone fallback failed", e)
        }
    }
}
