import 'package:prayer_cast/home_delivery/common/scheduler.dart';
import 'package:prayer_cast/home_delivery/coordination/election.dart';
import 'package:prayer_cast/home_delivery/coordination/election_auth.dart';
import 'package:prayer_cast/home_delivery/coordination/election_message.dart';
import 'package:prayer_cast/home_delivery/coordination/peer_registry.dart';
import 'package:prayer_cast/home_delivery/coordination/unicast_transport.dart';

/// Default household election secret for in-process multi-peer tests.
const kTestElectionSecret = 'test-household-election-secret';

/// Builds in-process peers that share one discovery mesh + unicast fabric.
final class FakePeer {
  FakePeer({
    required this.deviceId,
    required this.priority,
    required this.fingerprintShort,
    required InMemoryUnicastNetwork network,
    required InMemoryDiscoveryMesh mesh,
    this.clockOffset = Duration.zero,
    this.electionSecret = kTestElectionSecret,
  })  : transport = network.create(),
        discovery = InMemoryAdzanDiscovery(mesh) {
    discovery.endpoint = transport.localEndpoint;
    registry = PeerRegistry(
      discovery: discovery,
      homeFingerprintShort: fingerprintShort,
    );
  }

  final String deviceId;
  final int priority;
  final String fingerprintShort;
  final Duration clockOffset;
  final String electionSecret;
  final InMemoryUnicastTransport transport;
  final InMemoryAdzanDiscovery discovery;
  late final PeerRegistry registry;

  Election? election;

  ElectionAuth get auth => ElectionAuth(electionSecret);

  Future<void> startAdvertising() {
    return registry.start(
      deviceId: deviceId,
      priority: priority,
      state: PeerAdState.idle,
      udpPort: transport.localEndpoint.port,
    );
  }

  Future<ElectionResult> runElection({
    required String sessionId,
    required DateTime scheduledAzan,
    required Scheduler scheduler,
    Future<void> Function()? onPrepare,
    Future<void> Function()? onLead,
  }) {
    election = Election(
      sessionId: sessionId,
      deviceId: deviceId,
      basePriority: priority,
      scheduledAzan: scheduledAzan,
      sharedSecret: electionSecret,
      registry: registry,
      transport: transport,
      scheduler: scheduler,
      clockOffset: clockOffset,
    );
    return election!.run(onPrepare: onPrepare, onLead: onLead);
  }

  Future<void> dispose() async {
    await election?.cancel();
    await registry.stop();
    await transport.close();
  }
}

final class FakeHousehold {
  FakeHousehold({
    required this.fingerprintShort,
    this.electionSecret = kTestElectionSecret,
  })  : network = InMemoryUnicastNetwork(),
        mesh = InMemoryDiscoveryMesh();

  final String fingerprintShort;
  final String electionSecret;
  final InMemoryUnicastNetwork network;
  final InMemoryDiscoveryMesh mesh;
  final List<FakePeer> peers = [];

  FakePeer addPeer({
    required String deviceId,
    required int priority,
    Duration clockOffset = Duration.zero,
    String? fingerprintShort,
    String? electionSecret,
  }) {
    final peer = FakePeer(
      deviceId: deviceId,
      priority: priority,
      fingerprintShort: fingerprintShort ?? this.fingerprintShort,
      network: network,
      mesh: mesh,
      clockOffset: clockOffset,
      electionSecret: electionSecret ?? this.electionSecret,
    );
    peers.add(peer);
    return peer;
  }

  Future<void> startAll() async {
    for (final peer in peers) {
      await peer.startAdvertising();
    }
  }

  Future<void> dispose() async {
    for (final peer in peers) {
      await peer.dispose();
    }
  }
}
