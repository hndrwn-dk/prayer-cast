import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import '../common/logger.dart';

/// A single mDNS/NSD service sighting used by presence (§3.3) and Signal A.
///
/// WHY: Keep `nsd` behind a port so unit tests can inject fake peers without
/// touching the radio, and so presence never depends on Flutter plugin
/// lifecycle during pure Dart tests.
final class DiscoveredService {
  const DiscoveredService({
    required this.instanceName,
    required this.serviceType,
    this.txt = const {},
    this.host,
  });

  final String instanceName;
  final String serviceType;

  /// TXT keys as UTF-8 strings (values decoded lossily when non-UTF8).
  final Map<String, String> txt;

  /// Resolved host when available (Cast receiver IP for §5.2).
  final InternetAddress? host;

  /// Stable instance id per §3.3: Cast `id` TXT when present, else
  /// `instanceName@serviceType`.
  String get stableInstanceId {
    final castId = txt['id'];
    if (castId != null && castId.isNotEmpty) {
      return castId;
    }
    return '$instanceName@$serviceType';
  }
}

/// Browses one or more DNS-SD service types for a bounded budget.
abstract interface class MdnsBrowser {
  /// Discover services of [serviceTypes] until [budget] elapses or
  /// [shouldStop] returns true (early-exit, e.g. Signal A found).
  Future<List<DiscoveredService>> browse({
    required List<String> serviceTypes,
    required Duration budget,
    bool Function(List<DiscoveredService> soFar)? shouldStop,
  });
}

/// Production browser backed by package `nsd` (Bonjour / NsdManager).
///
/// No multicast sockets are opened directly — discovery goes through the
/// platform NSD APIs (hard requirement #1 / §4.2).
final class NsdMdnsBrowser implements MdnsBrowser {
  NsdMdnsBrowser({HomeDeliveryLogger logger = const SilentLogger()})
      : _logger = logger;

  final HomeDeliveryLogger _logger;

  @override
  Future<List<DiscoveredService>> browse({
    required List<String> serviceTypes,
    required Duration budget,
    bool Function(List<DiscoveredService> soFar)? shouldStop,
  }) async {
    final found = <String, DiscoveredService>{};
    final discoveries = <nsd.Discovery>[];

    try {
      for (final type in serviceTypes) {
        final discovery = await nsd.startDiscovery(type, autoResolve: true);
        discoveries.add(discovery);
        discovery.addServiceListener((service, status) {
          if (status != nsd.ServiceStatus.found) return;
          final mapped = _mapService(service);
          if (mapped == null) return;
          found[mapped.stableInstanceId] = mapped;
        });
      }

      final deadline = DateTime.now().add(budget);
      while (DateTime.now().isBefore(deadline)) {
        final snapshot = found.values.toList(growable: false);
        if (shouldStop != null && shouldStop(snapshot)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } on nsd.NsdError catch (e, st) {
      _logger.error(
        'NSD browse failed: ${e.message}',
        tag: 'NsdMdnsBrowser',
        error: e,
        stackTrace: st,
      );
      throw PresenceBrowseFailure(
        'NSD browse failed: ${e.cause.name} — ${e.message}',
        cause: e,
      );
    } catch (e, st) {
      _logger.error(
        'Unexpected browse failure',
        tag: 'NsdMdnsBrowser',
        error: e,
        stackTrace: st,
      );
      throw PresenceBrowseFailure('Unexpected browse failure: $e', cause: e);
    } finally {
      for (final discovery in discoveries) {
        try {
          await nsd.stopDiscovery(discovery);
        } catch (e, st) {
          _logger.warn(
            'stopDiscovery failed',
            tag: 'NsdMdnsBrowser',
            error: e,
            stackTrace: st,
          );
        }
      }
    }

    return found.values.toList(growable: false);
  }

  DiscoveredService? _mapService(nsd.Service service) {
    final name = service.name;
    final type = service.type;
    if (name == null || type == null) return null;
    return DiscoveredService(
      instanceName: name,
      serviceType: type,
      txt: _decodeTxt(service.txt),
      host: _resolveHost(service),
    );
  }

  InternetAddress? _resolveHost(nsd.Service service) {
    final addresses = service.addresses;
    if (addresses != null && addresses.isNotEmpty) {
      for (final a in addresses) {
        if (a.type == InternetAddressType.IPv4 && !a.isLoopback) return a;
      }
      return addresses.first;
    }
    final host = service.host;
    if (host == null || host.isEmpty) return null;
    try {
      return InternetAddress(host);
    } on ArgumentError {
      return null;
    }
  }

  Map<String, String> _decodeTxt(Map<String, Uint8List?>? txt) {
    if (txt == null) return const {};
    final out = <String, String>{};
    txt.forEach((key, value) {
      if (value == null) {
        out[key] = '';
      } else {
        out[key] = utf8.decode(value, allowMalformed: true);
      }
    });
    return out;
  }
}

/// Typed failure when mDNS/NSD browse cannot complete (§ hard req #3).
final class PresenceBrowseFailure implements Exception {
  PresenceBrowseFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PresenceBrowseFailure: $message';
}
