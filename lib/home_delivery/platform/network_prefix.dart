import 'package:flutter/services.dart';

import '../common/logger.dart';

/// One local IPv4 address with its CIDR prefix length from the OS.
final class InterfacePrefix {
  const InterfacePrefix({
    required this.name,
    required this.address,
    required this.prefixLength,
  });

  final String name;

  /// Dotted IPv4, e.g. `192.168.1.20`.
  final String address;

  /// CIDR prefix length 0–32.
  final int prefixLength;
}

/// Looks up per-interface IPv4 prefix lengths (netmasks).
///
/// WHY: `dart:io` [NetworkInterface] does not expose netmasks. Wrong assumed
/// /24 is the common cause of Cast connecting then going silent (VPN/hotspot).
abstract interface class NetworkPrefixLookup {
  Future<List<InterfacePrefix>> listPrefixLengths();
}

/// MethodChannel bridge — `prayer_cast/network_prefix`.
final class MethodChannelNetworkPrefix implements NetworkPrefixLookup {
  MethodChannelNetworkPrefix({
    MethodChannel? methodChannel,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _methods = methodChannel ??
            const MethodChannel('prayer_cast/network_prefix'),
        _logger = logger;

  final MethodChannel _methods;
  final HomeDeliveryLogger _logger;

  @override
  Future<List<InterfacePrefix>> listPrefixLengths() async {
    try {
      final raw = await _methods.invokeMethod<List<Object?>>('listIPv4Prefixes');
      if (raw == null) return const [];
      final result = <InterfacePrefix>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = <String, Object?>{
          for (final e in item.entries) e.key.toString(): e.value,
        };
        final name = map['name'] as String?;
        final address = map['address'] as String?;
        final prefix = (map['prefixLength'] as num?)?.toInt();
        if (name == null || address == null || prefix == null) continue;
        if (prefix < 0 || prefix > 32) continue;
        result.add(
          InterfacePrefix(
            name: name,
            address: address,
            prefixLength: prefix,
          ),
        );
      }
      return result;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'NetworkPrefix.listIPv4Prefixes failed',
        tag: 'NetworkPrefix',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
