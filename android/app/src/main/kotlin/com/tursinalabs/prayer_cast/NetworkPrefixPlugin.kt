package com.tursinalabs.prayer_cast

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Per-interface IPv4 CIDR prefix lengths for Cast interface selection (§5.2).
 *
 * Channel: prayer_cast/network_prefix
 */
class NetworkPrefixPlugin : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listIPv4Prefixes" -> result.success(listIPv4Prefixes())
            else -> result.notImplemented()
        }
    }

    private fun listIPv4Prefixes(): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return out
        while (interfaces.hasMoreElements()) {
            val nif = interfaces.nextElement()
            if (!nif.isUp || nif.isLoopback) continue
            for (addr in nif.interfaceAddresses) {
                val inet = addr.address
                if (inet !is Inet4Address || inet.isLoopbackAddress) continue
                val host = inet.hostAddress ?: continue
                out.add(
                    mapOf(
                        "name" to nif.name,
                        "address" to host,
                        "prefixLength" to addr.networkPrefixLength.toInt(),
                    ),
                )
            }
        }
        return out
    }

    companion object {
        const val CHANNEL = "prayer_cast/network_prefix"

        fun registerWith(flutterEngine: FlutterEngine) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).setMethodCallHandler(NetworkPrefixPlugin())
        }
    }
}
