import Flutter
import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Per-interface IPv4 CIDR prefix lengths for Cast interface selection (§5.2).
///
/// Channel: prayer_cast/network_prefix
public class NetworkPrefixPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "prayer_cast/network_prefix",
      binaryMessenger: registrar.messenger()
    )
    let instance = NetworkPrefixPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listIPv4Prefixes":
      result(listIPv4Prefixes())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func listIPv4Prefixes() -> [[String: Any]] {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
      return []
    }
    defer { freeifaddrs(first) }

    var out: [[String: Any]] = []
    var ptr: UnsafeMutablePointer<ifaddrs>? = first
    while let current = ptr {
      let iface = current.pointee
      defer { ptr = iface.ifa_next }

      guard let addrPtr = iface.ifa_addr, let maskPtr = iface.ifa_netmask else {
        continue
      }
      guard addrPtr.pointee.sa_family == UInt8(AF_INET) else { continue }

      let flags = Int32(iface.ifa_flags)
      if (flags & IFF_LOOPBACK) != 0 { continue }
      if (flags & IFF_UP) == 0 { continue }

      let name = String(cString: iface.ifa_name)
      let address = ipv4String(from: addrPtr)
      let prefix = prefixLength(from: maskPtr)
      guard let address, let prefix else { continue }

      out.append([
        "name": name,
        "address": address,
        "prefixLength": prefix,
      ])
    }
    return out
  }

  private func ipv4String(from sa: UnsafePointer<sockaddr>) -> String? {
    sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
      var addr = sin.pointee.sin_addr
      var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
      guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
        return nil
      }
      return String(cString: buffer)
    }
  }

  private func prefixLength(from sa: UnsafePointer<sockaddr>) -> Int? {
    sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
      let mask = UInt32(bigEndian: sin.pointee.sin_addr.s_addr)
      if mask == 0 { return 0 }
      // Count leading ones in the netmask.
      var bits = 0
      var remaining = mask
      while remaining & 0x8000_0000 != 0 {
        bits += 1
        remaining <<= 1
      }
      // Reject non-contiguous masks.
      if remaining != 0 { return nil }
      return bits
    }
  }
}
