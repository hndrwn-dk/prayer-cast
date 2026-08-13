import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../common/logger.dart';

/// Unicast UDP endpoint address for election messaging (§4.2).
///
/// WHY: Discovery is Bonjour/NSD; all CLAIM/LEAD/PLAYING/YIELD bytes travel
/// unicast. No multicast group addresses are used anywhere.
final class PeerEndpoint {
  const PeerEndpoint({required this.host, required this.port});

  final InternetAddress host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is PeerEndpoint &&
      other.port == port &&
      other.host.address == host.address;

  @override
  int get hashCode => Object.hash(host.address, port);

  @override
  String toString() => '${host.address}:$port';
}

/// A datagram received on the local unicast socket.
final class IncomingDatagram {
  const IncomingDatagram({required this.from, required this.bytes});

  final PeerEndpoint from;
  final Uint8List bytes;
}

/// Unicast UDP transport for election messages (hard requirement #1).
abstract interface class UnicastTransport {
  PeerEndpoint get localEndpoint;

  Stream<IncomingDatagram> get incoming;

  Future<void> send(PeerEndpoint to, List<int> bytes);

  Future<void> close();
}

/// Production transport bound to an ephemeral UDP port on [InternetAddress.anyIPv4].
final class UdpUnicastTransport implements UnicastTransport {
  UdpUnicastTransport._(this._socket, this.localEndpoint, this._logger);

  final RawDatagramSocket _socket;
  final HomeDeliveryLogger _logger;
  final StreamController<IncomingDatagram> _controller =
      StreamController<IncomingDatagram>.broadcast(sync: true);
  StreamSubscription<RawSocketEvent>? _sub;

  @override
  final PeerEndpoint localEndpoint;

  static Future<UdpUnicastTransport> bind({
    HomeDeliveryLogger logger = const SilentLogger(),
  }) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final endpoint = PeerEndpoint(
        host: InternetAddress.anyIPv4,
        port: socket.port,
      );
      final transport = UdpUnicastTransport._(socket, endpoint, logger);
      transport._sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        transport._controller.add(
          IncomingDatagram(
            from: PeerEndpoint(host: datagram.address, port: datagram.port),
            bytes: datagram.data,
          ),
        );
      });
      return transport;
    } on SocketException catch (e, st) {
      logger.error('UDP bind failed', tag: 'UdpUnicastTransport', error: e, stackTrace: st);
      throw UnicastTransportFailure('UDP bind failed: $e', cause: e);
    }
  }

  @override
  Stream<IncomingDatagram> get incoming => _controller.stream;

  @override
  Future<void> send(PeerEndpoint to, List<int> bytes) async {
    try {
      _socket.send(bytes, to.host, to.port);
    } on SocketException catch (e, st) {
      _logger.error(
        'UDP send failed to $to',
        tag: 'UdpUnicastTransport',
        error: e,
        stackTrace: st,
      );
      throw UnicastTransportFailure('UDP send failed to $to: $e', cause: e);
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _socket.close();
    await _controller.close();
  }
}

/// Typed transport failure (hard requirement #3).
final class UnicastTransportFailure implements Exception {
  UnicastTransportFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'UnicastTransportFailure: $message';
}

/// In-process unicast fabric for multi-device election tests.
///
/// Routes datagrams by [PeerEndpoint] with no sockets and no multicast.
final class InMemoryUnicastNetwork {
  final Map<int, InMemoryUnicastTransport> _byPort = {};
  int _nextPort = 40000;

  /// When set, returning true drops the datagram (UDP loss simulation).
  bool Function(PeerEndpoint from, PeerEndpoint to, List<int> bytes)? shouldDrop;

  InMemoryUnicastTransport create({InternetAddress? host}) {
    final port = _nextPort++;
    final endpoint = PeerEndpoint(
      host: host ?? InternetAddress.loopbackIPv4,
      port: port,
    );
    final transport = InMemoryUnicastTransport._(this, endpoint);
    _byPort[port] = transport;
    return transport;
  }

  void _send(PeerEndpoint from, PeerEndpoint to, List<int> bytes) {
    if (shouldDrop?.call(from, to, bytes) ?? false) {
      return;
    }
    final target = _byPort[to.port];
    if (target == null || target._closed) {
      throw UnicastTransportFailure('No in-memory peer at $to');
    }
    target._controller.add(
      IncomingDatagram(from: from, bytes: Uint8List.fromList(bytes)),
    );
  }

  void _remove(int port) {
    _byPort.remove(port);
  }
}

final class InMemoryUnicastTransport implements UnicastTransport {
  InMemoryUnicastTransport._(this._network, this.localEndpoint);

  final InMemoryUnicastNetwork _network;

  @override
  final PeerEndpoint localEndpoint;

  final StreamController<IncomingDatagram> _controller =
      StreamController<IncomingDatagram>.broadcast(sync: true);
  bool _closed = false;

  @override
  Stream<IncomingDatagram> get incoming => _controller.stream;

  @override
  Future<void> send(PeerEndpoint to, List<int> bytes) async {
    if (_closed) {
      throw UnicastTransportFailure('Transport closed');
    }
    _network._send(localEndpoint, to, bytes);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _network._remove(localEndpoint.port);
    await _controller.close();
  }
}
