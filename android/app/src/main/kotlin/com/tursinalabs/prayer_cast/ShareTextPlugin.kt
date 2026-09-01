package com.tursinalabs.prayer_cast

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Opens the system share sheet with plain text (Settings → Share Prayer Cast). */
object ShareTextPlugin {
    const val CHANNEL = "prayer_cast/share"

    fun bind(engine: FlutterEngine, host: MainActivity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.arguments as? String
                        if (text.isNullOrBlank()) {
                            result.error("bad_args", "text required", null)
                            return@setMethodCallHandler
                        }
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        host.startActivity(Intent.createChooser(send, null))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
