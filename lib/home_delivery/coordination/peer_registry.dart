import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import '../common/logger.dart';
import 'election_message.dart';
import 'unicast_transport.dart';

/// A peer discovered via `_adzan._tcp` (spec §4.3).
final class DiscoveredPeer {
  const DiscoveredPeer({
    required this.deviceId,
    required this.priority,
    required this.state,
    required this.fingerprintShort,
    required this.endpoint,
    required this.instanceName,
    this.protocolVersion = 1,
  });

  final String deviceId;
  final int priority;
  final PeerAdState state;
  final String fingerprintShort;
  final PeerEndpoint endpoint;
  final String instanceName;
  final int protocolVersion;
}

/// Local advertisement contents for `_adzan._tcp` TXT records (§4.3).
final class LocalPeerAdvertisement {
  const LocalPeerAdvertisement({
    required this.deviceId,
    required this.priority,
    required this.state,
    required this.fingerprintShort,
    required this.port,
  });

  final String deviceId;
  final int priority;
  final PeerAdState state;
  final String fingerprintShort;
  final int port;

  String get instanceName {
    final compact = deviceId.replaceAll('-', '');
    final prefix = compact.length >= 8 ? compact.substring(0, 8) : compact;
    return 'adzan-$prefix';
  }

  Map<String, Uint8List?> toTxt() => {
        'v': Uint8List.fromList(utf8.encode('1')),
        'id': Uint8List.fromList(utf8.encode(deviceId)),
        'pri': Uint8List.fromList(utf8.encode('$priority')),
        'st': Uint8List.fromList(utf8.encode(state.wire)),
        'fp': Uint8List.fromList(utf8.encode(fingerprintShort)),
      };
}

/// Port for advertising/browsing `_adzan._tcp` without binding tests to NSD.
abstract interface class AdzanDiscovery {
  Future<void> advertise(LocalPeerAdvertisement advertisement);

  Future<void> update(LocalPeerAdvertisement advertisement);

  Future<void> stopAdvertising();

  Future<void> startBrowsing();

  Future<void> stopBrowsing();

  List<DiscoveredPeer> get peers;

  Stream<List<DiscoveredPeer>> get peerChanges;
}

/// NSD/Bonjour advertise + browse for `_adzan._tcp` peers (spec §4.3).
///
/// WHY: Raw UDP multicast needs the iOS multicast entitlement and is flaky on
/// consumer APs (§4.2). Bonjour/NSD discovers peers; messaging is unicast UDP
/// only — no multicast sockets anywhere (hard requirement #1).
final class PeerRegistry {
  PeerRegistry({
    required AdzanDiscovery discovery,
    required this.homeFingerprintShort,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _discovery = discovery,
        _logger = logger;

  static const String serviceType = '_adzan._tcp';
  static const int protocolVersion = 1;

  final AdzanDiscovery _discovery;
  final String homeFingerprintShort;
  final HomeDeliveryLogger _logger;

  /// Peers sharing our home fingerprint (cross-house isolation).
  List<DiscoveredPeer> get homePeers => _discovery.peers
      .where(
        (p) =>
            p.fingerprintShort == homeFingerprintShort &&
            p.protocolVersion == protocolVersion,
      )
      .toList(growable: false);

  Stream<List<DiscoveredPeer>> get peerChanges => _discovery.peerChanges;

  Future<void> start({
    required String deviceId,
    required int priority,
    required PeerAdState state,
    required int udpPort,
  }) async {
    final ad = LocalPeerAdvertisement(
      deviceId: deviceId,
      priority: priority,
      state: state,
      fingerprintShort: homeFingerprintShort,
      port: udpPort,
    );
    await _discovery.advertise(ad);
    await _discovery.startBrowsing();
    _logger.info(
      'PeerRegistry started as ${ad.instanceName}',
      tag: 'PeerRegistry',
    );
  }

  Future<void> updateState({
    required String deviceId,
    required int priority,
    required PeerAdState state,
    required int udpPort,
  }) {
    return _discovery.update(
      LocalPeerAdvertisement(
        deviceId: deviceId,
        priority: priority,
        state: state,
        fingerprintShort: homeFingerprintShort,
        port: udpPort,
      ),
    );
  }

  Future<void> stop() async {
    await _discovery.stopBrowsing();
    await _discovery.stopAdvertising();
  }
}

/// Production discovery via package `nsd`.
final class NsdAdzanDiscovery implements AdzanDiscovery {
  NsdAdzanDiscovery({HomeDeliveryLogger logger = const SilentLogger()})
      : _logger = logger;

  final HomeDeliveryLogger _logger;
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  LocalPeerAdvertisement? _current;
  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _changes =
      StreamController<List<DiscoveredPeer>>.broadcast();

  @override
  List<DiscoveredPeer> get peers => _peers.values.toList(growable: false);

  @override
  Stream<List<DiscoveredPeer>> get peerChanges => _changes.stream;

  @override
  Future<void> advertise(LocalPeerAdvertisement advertisement) async {
    _current = advertisement;
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: advertisement.instanceName,
          type: PeerRegistry.serviceType,
          port: advertisement.port,
          txt: advertisement.toTxt(),
        ),
      );
    } on nsd.NsdError catch (e, st) {
      _logger.error(
        'Advertise failed',
        tag: 'NsdAdzanDiscovery',
        error: e,
        stackTrace: st,
      );
      throw PeerDiscoveryFailure('Advertise failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> update(LocalPeerAdvertisement advertisement) async {
    await stopAdvertising();
    await advertise(advertisement);
  }

  @override
  Future<void> stopAdvertising() async {
    final reg = _registration;
    _registration = null;
    if (reg != null) {
      try {
        await nsd.unregister(reg);
      } catch (e, st) {
        _logger.warn(
          'Unregister failed',
          tag: 'NsdAdzanDiscovery',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Future<void> startBrowsing() async {
    try {
      final discovery = await nsd.startDiscovery(
        PeerRegistry.serviceType,
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.any,
      );
      _discovery = discovery;
      discovery.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.lost) {
          final name = service.name;
          if (name != null) {
            _peers.removeWhere((_, p) => p.instanceName == name);
            _emit();
          }
          return;
        }
        if (status != nsd.ServiceStatus.found) return;
        final peer = _mapPeer(service);
        if (peer == null) return;
        if (_current != null && peer.deviceId == _current!.deviceId) return;
        _peers[peer.deviceId] = peer;
        _emit();
      });
    } on nsd.NsdError catch (e, st) {
      _logger.error(
        'Browse failed',
        tag: 'NsdAdzanDiscovery',
        error: e,
        stackTrace: st,
      );
      throw PeerDiscoveryFailure('Browse failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> stopBrowsing() async {
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      try {
        await nsd.stopDiscovery(discovery);
      } catch (e, st) {
        _logger.warn(
          'stopDiscovery failed',
          tag: 'NsdAdzanDiscovery',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  DiscoveredPeer? _mapPeer(nsd.Service service) {
    final name = service.name;
    final host = service.host;
    final port = service.port;
    if (name == null || host == null || port == null) return null;
    final txt = _decodeTxt(service.txt);
    final id = txt['id'];
    final pri = int.tryParse(txt['pri'] ?? '');
    final st = txt['st'];
    final fp = txt['fp'];
    final v = int.tryParse(txt['v'] ?? '1') ?? 1;
    if (id == null || pri == null || st == null || fp == null) return null;
    final addresses = service.addresses;
    final address = (addresses != null && addresses.isNotEmpty)
        ? addresses.first
        : InternetAddress(host);
    try {
      return DiscoveredPeer(
        deviceId: id,
        priority: pri,
        state: PeerAdState.fromWire(st),
        fingerprintShort: fp,
        endpoint: PeerEndpoint(host: address, port: port),
        instanceName: name,
        protocolVersion: v,
      );
    } on FormatException {
      return null;
    }
  }

  Map<String, String> _decodeTxt(Map<String, Uint8List?>? txt) {
    if (txt == null) return const {};
    return {
      for (final e in txt.entries)
        e.key: e.value == null
            ? ''
            : utf8.decode(e.value!, allowMalformed: true),
    };
  }

  void _emit() {
    if (!_changes.isClosed) {
      _changes.add(peers);
    }
  }
}

/// In-process discovery mesh for multi-device election tests.
final class InMemoryAdzanDiscovery implements AdzanDiscovery {
  InMemoryAdzanDiscovery(this._mesh);

  final InMemoryDiscoveryMesh _mesh;
  LocalPeerAdvertisement? _ad;
  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _changes =
      StreamController<List<DiscoveredPeer>>.broadcast();
  bool _browsing = false;

  /// Wire the UDP endpoint used in TXT/port so peers can unicast.
  PeerEndpoint? endpoint;

  @override
  List<DiscoveredPeer> get peers => _peers.values.toList(growable: false);

  @override
  Stream<List<DiscoveredPeer>> get peerChanges => _changes.stream;

  @override
  Future<void> advertise(LocalPeerAdvertisement advertisement) async {
    _ad = advertisement;
    _mesh.publish(this);
  }

  @override
  Future<void> update(LocalPeerAdvertisement advertisement) async {
    _ad = advertisement;
    _mesh.publish(this);
  }

  @override
  Future<void> stopAdvertising() async {
    final id = _ad?.deviceId;
    _ad = null;
    _mesh.unpublish(this, id);
  }

  @override
  Future<void> startBrowsing() async {
    _browsing = true;
    _mesh.refresh(this);
  }

  @override
  Future<void> stopBrowsing() async {
    _browsing = false;
    _peers.clear();
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  void see(DiscoveredPeer peer) {
    if (!_browsing) return;
    if (_ad != null && peer.deviceId == _ad!.deviceId) return;
    _peers[peer.deviceId] = peer;
    if (!_changes.isClosed) {
      _changes.add(peers);
    }
  }

  void lose(String deviceId) {
    _peers.remove(deviceId);
    if (!_changes.isClosed) {
      _changes.add(peers);
    }
  }

  LocalPeerAdvertisement? get advertisement => _ad;
}

final class InMemoryDiscoveryMesh {
  final Set<InMemoryAdzanDiscovery> _nodes = {};

  void publish(InMemoryAdzanDiscovery node) {
    _nodes.add(node);
    for (final other in _nodes) {
      refresh(other);
    }
  }

  void unpublish(InMemoryAdzanDiscovery node, String? deviceId) {
    _nodes.remove(node);
    if (deviceId != null) {
      for (final other in _nodes) {
        other.lose(deviceId);
      }
    }
  }

  void refresh(InMemoryAdzanDiscovery viewer) {
    for (final node in _nodes) {
      final ad = node.advertisement;
      final endpoint = node.endpoint;
      if (ad == null || endpoint == null) continue;
      viewer.see(
        DiscoveredPeer(
          deviceId: ad.deviceId,
          priority: ad.priority,
          state: ad.state,
          fingerprintShort: ad.fingerprintShort,
          endpoint: endpoint,
          instanceName: ad.instanceName,
        ),
      );
    }
  }
}

final class PeerDiscoveryFailure implements Exception {
  PeerDiscoveryFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PeerDiscoveryFailure: $message';
}
