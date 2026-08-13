import 'dart:io';

import '../common/logger.dart';
import '../logging/outcome.dart';
import '../platform/network_prefix.dart';

/// A local IPv4 interface with its subnet mask.
final class NetworkIface {
  const NetworkIface({
    required this.name,
    required this.address,
    required this.netmask,
  });

  final String name;
  final InternetAddress address;
  final InternetAddress netmask;
}

/// Enumerates local interfaces (injectable for unit tests).
abstract interface class NetworkInterfaceSource {
  Future<List<NetworkIface>> listIPv4();
}

/// Converts a CIDR prefix length (0–32) to a dotted IPv4 netmask.
InternetAddress netmaskFromPrefixLength(int prefixLength) {
  if (prefixLength < 0 || prefixLength > 32) {
    throw ArgumentError.value(
      prefixLength,
      'prefixLength',
      'must be between 0 and 32',
    );
  }
  final mask = prefixLength == 0
      ? 0
      : (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
  return InternetAddress(
    '${(mask >> 24) & 0xFF}.'
    '${(mask >> 16) & 0xFF}.'
    '${(mask >> 8) & 0xFF}.'
    '${mask & 0xFF}',
  );
}

/// Production source: `dart:io` address list + platform CIDR prefix lengths.
final class SystemNetworkInterfaces implements NetworkInterfaceSource {
  SystemNetworkInterfaces({
    NetworkPrefixLookup? prefixLookup,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _prefixLookup =
            prefixLookup ?? MethodChannelNetworkPrefix(logger: logger),
        _logger = logger;

  static final InternetAddress _fallbackNetmask =
      InternetAddress('255.255.255.0');

  final NetworkPrefixLookup _prefixLookup;
  final HomeDeliveryLogger _logger;

  @override
  Future<List<NetworkIface>> listIPv4() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    final prefixesByAddress = <String, int>{};
    try {
      final prefixes = await _prefixLookup.listPrefixLengths();
      for (final p in prefixes) {
        prefixesByAddress[p.address] = p.prefixLength;
      }
    } catch (e, st) {
      _logger.warn(
        'Platform netmask lookup failed — assuming /24 for all interfaces',
        tag: 'SystemNetworkInterfaces',
        error: e,
        stackTrace: st,
      );
    }

    final result = <NetworkIface>[];
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final prefix = prefixesByAddress[addr.address];
        final InternetAddress netmask;
        if (prefix != null) {
          netmask = netmaskFromPrefixLength(prefix);
        } else {
          _logger.warn(
            'No prefix length for ${iface.name} ${addr.address} — assuming /24',
            tag: 'SystemNetworkInterfaces',
          );
          netmask = _fallbackNetmask;
        }
        result.add(
          NetworkIface(
            name: iface.name,
            address: addr,
            netmask: netmask,
          ),
        );
      }
    }
    return result;
  }
}

/// Picks the LAN interface whose subnet contains the Cast receiver (§5.2).
///
/// WHY: On a phone with VPN + hotspot + Wi-Fi, advertising the wrong IP is the
/// most common cause of "speaker connects then goes silent". No shared subnet
/// ⇒ typed [NoRouteToReceiverFailure] / [Outcome.failedNoRoute].
final class InterfaceSelector {
  InterfaceSelector({
    NetworkInterfaceSource? source,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _source = source ?? SystemNetworkInterfaces(logger: logger),
        _logger = logger;

  final NetworkInterfaceSource _source;
  final HomeDeliveryLogger _logger;

  /// Returns the local IPv4 address that shares a subnet with [receiver].
  ///
  /// Throws [NoRouteToReceiverFailure] when none match.
  Future<InternetAddress> selectFor(InternetAddress receiver) async {
    if (receiver.type != InternetAddressType.IPv4) {
      throw NoRouteToReceiverFailure(
        'Receiver address is not IPv4: ${receiver.address}',
      );
    }

    final interfaces = await _source.listIPv4();
    for (final iface in interfaces) {
      if (sameSubnet(iface.address, iface.netmask, receiver)) {
        _logger.info(
          'Selected interface ${iface.name} (${iface.address.address}) '
          'for receiver ${receiver.address}',
          tag: 'InterfaceSelector',
        );
        return iface.address;
      }
    }

    throw NoRouteToReceiverFailure(
      'No local interface shares a subnet with ${receiver.address}',
    );
  }

  /// True when [a] and [b] are in the same subnet under [netmask].
  static bool sameSubnet(
    InternetAddress a,
    InternetAddress netmask,
    InternetAddress b,
  ) {
    final aBytes = a.rawAddress;
    final bBytes = b.rawAddress;
    final mBytes = netmask.rawAddress;
    if (aBytes.length != 4 || bBytes.length != 4 || mBytes.length != 4) {
      return false;
    }
    for (var i = 0; i < 4; i++) {
      if ((aBytes[i] & mBytes[i]) != (bBytes[i] & mBytes[i])) {
        return false;
      }
    }
    return true;
  }
}

/// No interface on the receiver's subnet (§5.2). Maps to [Outcome.failedNoRoute].
final class NoRouteToReceiverFailure implements Exception, OutcomeException {
  NoRouteToReceiverFailure(this.message);

  final String message;

  @override
  Outcome get outcome => Outcome.failedNoRoute;

  @override
  String toString() => 'NoRouteToReceiverFailure: $message';
}
