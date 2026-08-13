import 'dart:async';

import '../common/logger.dart';
import '../common/scheduler.dart';
import '../logging/outcome.dart';
import 'clock_skew.dart';
import 'device_identity.dart';
import 'election_auth.dart';
import 'election_message.dart';
import 'election_schedule.dart';
import 'peer_registry.dart';
import 'unicast_transport.dart';

/// CLAIM / LEAD / PLAYING / YIELD leader election (spec §4.6–§4.9).
///
/// WHY: N phones at home must produce exactly one cast. Election is anchored
/// to the scheduled azan epoch (hard requirement #4), with staggered failover
/// at T+4 / T+8 / T+12 and a solo fast path when no peers respond by T−22.
///
/// Wire messages are HMAC'd with [sharedSecret] (onboarding-shared). LEAD /
/// PLAYING / YIELD are accepted only from peers that appeared in the claim
/// ranking; CLAIM priority must be in 0–100.
final class Election {
  Election({
    required this.sessionId,
    required this.deviceId,
    required this.basePriority,
    required this.scheduledAzan,
    required String sharedSecret,
    required PeerRegistry registry,
    required UnicastTransport transport,
    required Scheduler scheduler,
    this.clockOffset = Duration.zero,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _auth = ElectionAuth(sharedSecret),
        _registry = registry,
        _transport = transport,
        _scheduler = scheduler,
        _logger = logger;

  final String sessionId;
  final String deviceId;
  final int basePriority;
  final DateTime scheduledAzan;

  /// Added to CLAIM.now / skew self-clock to simulate a wrong wall clock (§4.7).
  final Duration clockOffset;

  final ElectionAuth _auth;
  final PeerRegistry _registry;
  final UnicastTransport _transport;
  final Scheduler _scheduler;
  final HomeDeliveryLogger _logger;

  final Map<String, ClaimMessage> _claims = {};
  final Map<String, PeerEndpoint> _endpointsById = {};
  /// Device ids present in the claim-time ranking (self ∪ valid claimants).
  final Set<String> _claimRankedIds = {};

  StreamSubscription<IncomingDatagram>? _sub;
  Completer<void>? _playingHeard;
  Completer<void>? _leaderYielded;
  Completer<void>? _promotedLeadHeard;
  final Completer<void> _cancelled = Completer<void>();
  final Completer<String> _yieldRequested = Completer<String>();

  /// Rank-1 winner from claim-time ranking (unchanged when a backup LEADs).
  String? _expectedLeaderId;
  String? _currentLeaderId;
  List<PeerRank> _ranking = const [];
  int _effectivePriority = 0;
  bool _clockSkewLogged = false;
  bool _closed = false;
  bool _failoverExtendPending = false;
  bool _failoverExtended = false;
  bool _rankingFinalized = false;

  /// Run the full coordination protocol for this device.
  ///
  /// [onPrepare] is invoked for the leader at T−5 (HTTP + Cast pre-connect).
  /// [onLead] is invoked at T+0 when this device should `loadMedia`. When
  /// [onLead] completes successfully the election broadcasts PLAYING. If
  /// [onLead] throws, the device YIELDs.
  Future<ElectionResult> run({
    Future<void> Function()? onPrepare,
    Future<void> Function()? onLead,
  }) async {
    _effectivePriority = basePriority;
    _playingHeard = Completer<void>();
    _leaderYielded = Completer<void>();
    _promotedLeadHeard = Completer<void>();
    _sub = _transport.incoming.listen(
      _onDatagram,
      onError: (Object e, StackTrace st) {
        _logger.error(
          'Election transport error',
          tag: 'Election',
          error: e,
          stackTrace: st,
        );
      },
    );

    try {
      await _registry.updateState(
        deviceId: deviceId,
        priority: _effectivePriority,
        state: PeerAdState.claiming,
        udpPort: _transport.localEndpoint.port,
      );

      final claimOk = await _runClaimWindow();
      if (!claimOk) {
        return ElectionResult(
          role: ElectionRole.yielded,
          outcome: Outcome.suppressedNotLeader,
          peerCount: _claims.length,
          ranking: _ranking,
          clockSkewDetected: _clockSkewLogged,
          detail: 'cancelled during claim window',
        );
      }

      final role = _decideRole();
      switch (role) {
        case _Role.solo:
          return await _leadAs(
            role: ElectionRole.solo,
            onPrepare: onPrepare,
            onLead: onLead,
            peerCount: 0,
          );
        case _Role.leader:
          return await _leadAs(
            role: ElectionRole.leader,
            onPrepare: onPrepare,
            onLead: onLead,
            peerCount: _claims.length,
          );
        case _Role.follower:
          return await _follow(onPrepare: onPrepare, onLead: onLead);
      }
    } finally {
      await _cleanup();
    }
  }

  /// Abort without sending PLAYING (simulates process kill / Wi-Fi loss).
  Future<void> cancel() async {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    await _cleanup();
  }

  /// Drop out during prepare; followers promote immediately (§4.6).
  Future<void> yieldLeadership(String reason) async {
    if (!_yieldRequested.isCompleted) {
      _yieldRequested.complete(reason);
    }
    await _broadcastYield(reason);
  }

  Future<bool> _runClaimWindow() async {
    final claimStart = ElectionSchedule.at(
      scheduledAzan,
      ElectionSchedule.claimStart,
    );
    final claimEnd = ElectionSchedule.at(
      scheduledAzan,
      ElectionSchedule.claimEnd,
    );

    if (!await _waitOrCancel(claimStart)) return false;

    while (_scheduler.now().isBefore(claimEnd)) {
      if (_cancelled.isCompleted) return false;
      await _broadcastClaim();
      final next = _scheduler.now().add(ElectionSchedule.claimInterval);
      final wake = next.isAfter(claimEnd) ? claimEnd : next;
      if (!await _waitOrCancel(wake)) return false;
    }

    await _broadcastClaim();
    return true;
  }

  Future<void> _broadcastClaim() async {
    _refreshEndpoints();
    final msg = ClaimMessage(
      sessionId: sessionId,
      deviceId: deviceId,
      priority: _clampedPriority(_effectivePriority),
      nowEpochMs: _selfNowEpochMs(),
    );
    await _sendToKnownPeers(msg);
  }

  static int _clampedPriority(int priority) {
    if (priority < ClaimMessage.minPriority) return ClaimMessage.minPriority;
    if (priority > ClaimMessage.maxPriority) return ClaimMessage.maxPriority;
    return priority;
  }

  void _refreshEndpoints() {
    for (final peer in _registry.homePeers) {
      _endpointsById[peer.deviceId] = peer.endpoint;
    }
  }

  _Role _decideRole() {
    final peerClaims = _claims.values.toList(growable: false);
    final skew = ClockSkewAnalyzer.decide(
      selfDeviceId: deviceId,
      selfNowEpochMs: _selfNowEpochMs(),
      peerClaims: peerClaims,
    );
    if (skew.skewDetected) {
      _clockSkewLogged = true;
      _logger.warn(
        skew.twoDeviceTieBreak
            ? 'Clock skew with sole peer; lower deviceId leads'
            : 'Clock skew detected; demoted=${skew.demotedDeviceIds}',
        tag: 'Election',
      );
    }

    int priorityFor(String id, int advertised) {
      if (skew.demotedDeviceIds.contains(id)) return 0;
      return advertised;
    }

    _effectivePriority =
        _clampedPriority(priorityFor(deviceId, basePriority));

    // Solo fast path (§4.9): zero peer CLAIMs by T−22.
    if (peerClaims.isEmpty) {
      _ranking = [PeerRank(deviceId: deviceId, priority: _effectivePriority)];
      _claimRankedIds
        ..clear()
        ..add(deviceId);
      _rankingFinalized = true;
      return _Role.solo;
    }

    _ranking = [
      PeerRank(deviceId: deviceId, priority: _effectivePriority),
      for (final c in peerClaims)
        PeerRank(
          deviceId: c.deviceId,
          priority: priorityFor(c.deviceId, c.priority),
        ),
    ]..sort(DeviceIdentity.compareRank);

    _claimRankedIds
      ..clear()
      ..addAll(_ranking.map((r) => r.deviceId));
    _rankingFinalized = true;

    final winner = _ranking.first;
    if (winner.deviceId == deviceId) {
      return _Role.leader;
    }
    _expectedLeaderId = winner.deviceId;
    _currentLeaderId = winner.deviceId;
    return _Role.follower;
  }

  Future<ElectionResult> _leadAs({
    required ElectionRole role,
    required Future<void> Function()? onPrepare,
    required Future<void> Function()? onLead,
    required int peerCount,
  }) async {
    await _registry.updateState(
      deviceId: deviceId,
      priority: _effectivePriority,
      state: PeerAdState.leading,
      udpPort: _transport.localEndpoint.port,
    );

    final leadEnd = ElectionSchedule.at(
      scheduledAzan,
      ElectionSchedule.leadEnd,
    );
    // Original leader: one LEAD then wait until leadEnd (unchanged).
    // Promoted: announce immediately (twice, ~1s apart) before onPrepare so
    // lower ranks can delay their failover instead of double-casting.
    if (role == ElectionRole.leader) {
      await _sendToKnownPeers(
        LeadMessage(sessionId: sessionId, deviceId: deviceId),
      );
      if (!await _waitOrCancelOrYield(leadEnd)) {
        return _cancelledOrYielded(peerCount);
      }
    } else if (role == ElectionRole.promoted) {
      await _sendToKnownPeers(
        LeadMessage(sessionId: sessionId, deviceId: deviceId),
      );
      final repeatAt =
          _scheduler.now().add(ElectionSchedule.promotedLeadRepeat);
      if (!await _waitOrCancelOrYield(repeatAt)) {
        return _cancelledOrYielded(peerCount);
      }
      await _sendToKnownPeers(
        LeadMessage(sessionId: sessionId, deviceId: deviceId),
      );
    }

    final prepareAt = ElectionSchedule.at(
      scheduledAzan,
      ElectionSchedule.prepare,
    );
    if (!await _waitOrCancelOrYield(prepareAt)) {
      return _cancelledOrYielded(peerCount);
    }

    try {
      await (onPrepare?.call() ?? Future<void>.value());
    } catch (e, st) {
      _logger.error(
        'onPrepare failed; yielding',
        tag: 'Election',
        error: e,
        stackTrace: st,
      );
      await _broadcastYield('onPrepare failed: $e');
      final outcome =
          e is OutcomeException ? e.outcome : Outcome.failedCastConnect;
      return ElectionResult(
        role: ElectionRole.yielded,
        outcome: outcome,
        peerCount: peerCount,
        ranking: _ranking,
        clockSkewDetected: _clockSkewLogged,
        detail: e.toString(),
      );
    }

    final azan = ElectionSchedule.at(scheduledAzan, ElectionSchedule.azan);
    if (!await _waitOrCancelOrYield(azan)) {
      return _cancelledOrYielded(peerCount);
    }

    try {
      await (onLead?.call() ?? Future<void>.value());
    } catch (e, st) {
      _logger.error(
        'onLead failed; yielding',
        tag: 'Election',
        error: e,
        stackTrace: st,
      );
      await _broadcastYield('onLead failed: $e');
      final outcome = e is OutcomeException
          ? e.outcome
          : Outcome.failedLoadMedia;
      return ElectionResult(
        role: ElectionRole.yielded,
        outcome: outcome,
        peerCount: peerCount,
        ranking: _ranking,
        clockSkewDetected: _clockSkewLogged,
        detail: e.toString(),
      );
    }

    if (_cancelled.isCompleted) {
      return _cancelledOrYielded(peerCount);
    }

    await _registry.updateState(
      deviceId: deviceId,
      priority: _effectivePriority,
      state: PeerAdState.playing,
      udpPort: _transport.localEndpoint.port,
    );
    await _sendToKnownPeers(
      PlayingMessage(sessionId: sessionId, deviceId: deviceId),
    );

    return ElectionResult(
      role: role,
      outcome: Outcome.played,
      peerCount: peerCount,
      ranking: _ranking,
      clockSkewDetected: _clockSkewLogged,
    );
  }

  ElectionResult _cancelledOrYielded(int peerCount) {
    final yielded = _yieldRequested.isCompleted;
    return ElectionResult(
      role: ElectionRole.yielded,
      outcome: Outcome.suppressedNotLeader,
      peerCount: peerCount,
      ranking: _ranking,
      clockSkewDetected: _clockSkewLogged,
      detail: yielded ? 'yielded' : 'cancelled before PLAYING',
    );
  }

  int _selfNowEpochMs() =>
      _scheduler.now().add(clockOffset).millisecondsSinceEpoch;

  Future<ElectionResult> _follow({
    required Future<void> Function()? onPrepare,
    required Future<void> Function()? onLead,
  }) async {
    await _registry.updateState(
      deviceId: deviceId,
      priority: _effectivePriority,
      state: PeerAdState.idle,
      udpPort: _transport.localEndpoint.port,
    );

    final myRank = _ranking.indexWhere((r) => r.deviceId == deviceId);
    final failoverIndex = myRank - 1;
    final hasFailoverSlot = failoverIndex >= 0 &&
        failoverIndex < ElectionSchedule.failoverOffsets.length;
    DateTime? failoverAt = hasFailoverSlot
        ? ElectionSchedule.at(
            scheduledAzan,
            ElectionSchedule.failoverOffsets[failoverIndex],
          )
        : null;
    final giveUpAt = ElectionSchedule.at(
      scheduledAzan,
      ElectionSchedule.followerGiveUp,
    );

    while (!_cancelled.isCompleted) {
      if (_playingHeard?.isCompleted ?? false) {
        return ElectionResult(
          role: ElectionRole.follower,
          outcome: Outcome.suppressedNotLeader,
          peerCount: _claims.length,
          ranking: _ranking,
          clockSkewDetected: _clockSkewLogged,
          leaderId: _currentLeaderId,
        );
      }

      if (_failoverExtendPending) {
        _failoverExtendPending = false;
        // Rank-5+ has no failover slot — still must reset the completed
        // completer below or Future.any spins forever on a done future.
        if (failoverAt != null && !_failoverExtended) {
          _failoverExtended = true;
          failoverAt = failoverAt.add(ElectionSchedule.failoverStagger);
          _logger.info(
            'Honoring promoted LEAD; failover delayed to $failoverAt',
            tag: 'Election',
          );
        }
        _promotedLeadHeard = Completer<void>();
      }

      if (_leaderYielded?.isCompleted ?? false) {
        if (myRank == 1) {
          return await _leadAs(
            role: ElectionRole.promoted,
            onPrepare: onPrepare,
            onLead: onLead,
            peerCount: _claims.length,
          );
        }
        _leaderYielded = Completer<void>();
      }

      final now = _scheduler.now();
      if (failoverAt != null && !now.isBefore(failoverAt)) {
        if (!(_playingHeard?.isCompleted ?? false)) {
          return await _leadAs(
            role: ElectionRole.promoted,
            onPrepare: onPrepare,
            onLead: onLead,
            peerCount: _claims.length,
          );
        }
      }

      // Rank-5+ (no failover slot) — or any follower still waiting after the
      // last staggered window — must exit. Otherwise waitUntil(now+100ms)
      // spins forever, blocking orchestrator finally / FGS release / reschedule.
      if (!now.isBefore(giveUpAt)) {
        _logger.warn(
          'Follower give-up at $giveUpAt with no PLAYING '
          '(rank=${myRank + 1}, failoverAt=$failoverAt)',
          tag: 'Election',
        );
        return ElectionResult(
          role: ElectionRole.follower,
          outcome: Outcome.suppressedNotLeader,
          peerCount: _claims.length,
          ranking: _ranking,
          clockSkewDetected: _clockSkewLogged,
          leaderId: _currentLeaderId,
          detail: 'follower give-up after ${ElectionSchedule.followerGiveUp.inSeconds}s',
        );
      }

      final nextWake = _nextFollowerWake(failoverAt, giveUpAt);
      // Only wait on incomplete signals — a completed Completer in Future.any
      // would busy-spin microtasks and starve the scheduler.
      await Future.any([
        if (!(_playingHeard?.isCompleted ?? true)) _playingHeard!.future,
        if (_leaderYielded != null && !_leaderYielded!.isCompleted)
          _leaderYielded!.future,
        if (_promotedLeadHeard != null && !_promotedLeadHeard!.isCompleted)
          _promotedLeadHeard!.future,
        if (!_cancelled.isCompleted) _cancelled.future,
        _scheduler.waitUntil(nextWake),
      ]);
    }

    return ElectionResult(
      role: ElectionRole.yielded,
      outcome: Outcome.suppressedNotLeader,
      peerCount: _claims.length,
      ranking: _ranking,
      clockSkewDetected: _clockSkewLogged,
      detail: 'cancelled as follower',
    );
  }

  DateTime _nextFollowerWake(DateTime? failoverAt, DateTime giveUpAt) {
    final now = _scheduler.now();
    final candidates = <DateTime>[
      now.add(const Duration(milliseconds: 100)),
      if (failoverAt != null) failoverAt,
      giveUpAt,
    ]..sort();
    for (final c in candidates) {
      if (c.isAfter(now)) return c;
    }
    return giveUpAt;
  }

  Future<void> _broadcastYield(String reason) async {
    await _sendToKnownPeers(
      YieldMessage(sessionId: sessionId, deviceId: deviceId, reason: reason),
    );
    await _registry.updateState(
      deviceId: deviceId,
      priority: _effectivePriority,
      state: PeerAdState.idle,
      udpPort: _transport.localEndpoint.port,
    );
  }

  void _onDatagram(IncomingDatagram packet) {
    if (_closed) return;
    final ElectionMessage message;
    try {
      message = _auth.decodeVerified(packet.bytes);
    } on ElectionProtocolFailure catch (e, st) {
      _logger.warn(
        'Dropping bad election datagram',
        tag: 'Election',
        error: e,
        stackTrace: st,
      );
      return;
    }

    if (message.sessionId != sessionId) return;
    if (message.deviceId == deviceId) return;

    switch (message) {
      case ClaimMessage():
        _endpointsById.putIfAbsent(message.deviceId, () => packet.from);
        _claims[message.deviceId] = message;
      case LeadMessage():
        if (!_acceptFromClaimRanked(message)) return;
        _endpointsById.putIfAbsent(message.deviceId, () => packet.from);
        _onLeadMessage(message);
      case PlayingMessage():
        if (!_acceptFromClaimRanked(message)) return;
        _endpointsById.putIfAbsent(message.deviceId, () => packet.from);
        _currentLeaderId = message.deviceId;
        final c = _playingHeard;
        if (c != null && !c.isCompleted) c.complete();
      case YieldMessage():
        if (!_acceptFromClaimRanked(message)) return;
        _endpointsById.putIfAbsent(message.deviceId, () => packet.from);
        if (_currentLeaderId == null ||
            message.deviceId == _currentLeaderId) {
          _currentLeaderId = message.deviceId;
          final c = _leaderYielded;
          if (c != null && !c.isCompleted) c.complete();
        }
    }
  }

  /// LEAD / PLAYING / YIELD only from peers present in the claim ranking.
  bool _acceptFromClaimRanked(ElectionMessage message) {
    if (!_rankingFinalized) {
      // Still claiming — allow only senders that already sent a valid CLAIM.
      if (_claims.containsKey(message.deviceId)) return true;
      _logger.warn(
        'Ignoring ${message.type} from ${message.deviceId} '
        '(no CLAIM yet in this session)',
        tag: 'Election',
      );
      return false;
    }
    if (_claimRankedIds.contains(message.deviceId)) return true;
    _logger.warn(
      'Ignoring ${message.type} from ${message.deviceId} '
      '(not in claim-time ranking)',
      tag: 'Election',
    );
    return false;
  }

  void _onLeadMessage(LeadMessage message) {
    _currentLeaderId = message.deviceId;
    // Original leader's LEAD is expected; only a takeover LEAD can delay us.
    final expected = _expectedLeaderId;
    if (expected == null || message.deviceId == expected) {
      return;
    }
    if (_failoverExtended || _failoverExtendPending) {
      return;
    }
    if (!_isAcceptablePromotedLead(message.deviceId)) {
      _logger.warn(
        'Ignoring LEAD from ${message.deviceId} '
        '(outranked or unknown at claim time)',
        tag: 'Election',
      );
      return;
    }
    _failoverExtendPending = true;
    final c = _promotedLeadHeard;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Honor takeover LEAD only when sender ranked better-or-equal to self.
  bool _isAcceptablePromotedLead(String senderId) {
    PeerRank? sender;
    PeerRank? self;
    for (final r in _ranking) {
      if (r.deviceId == senderId) sender = r;
      if (r.deviceId == deviceId) self = r;
    }
    if (sender == null || self == null) return false;
    return DeviceIdentity.compareRank(sender, self) <= 0;
  }

  Future<void> _sendToKnownPeers(ElectionMessage message) async {
    _refreshEndpoints();
    final bytes = _auth.encodeSigned(message);
    final targets = {
      for (final e in _endpointsById.entries)
        if (e.key != deviceId) e.value,
    };
    for (final to in targets) {
      try {
        await _transport.send(to, bytes);
      } on UnicastTransportFailure catch (e, st) {
        _logger.warn(
          'Failed to send ${message.type} to $to',
          tag: 'Election',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<bool> _waitOrCancel(DateTime deadline) async {
    await Future.any([
      _scheduler.waitUntil(deadline),
      _cancelled.future,
    ]);
    return !_cancelled.isCompleted;
  }

  Future<bool> _waitOrCancelOrYield(DateTime deadline) async {
    await Future.any([
      _scheduler.waitUntil(deadline),
      _cancelled.future,
      _yieldRequested.future,
    ]);
    return !_cancelled.isCompleted && !_yieldRequested.isCompleted;
  }

  Future<void> _cleanup() async {
    _closed = true;
    await _sub?.cancel();
    _sub = null;
  }
}

enum _Role { solo, leader, follower }

/// Role this device took in the election (§6.1 `role` column).
enum ElectionRole {
  solo,
  leader,
  follower,
  promoted,
  yielded,
}

/// Final coordination result for one device, ready to log (§6.1 / §6.2).
final class ElectionResult {
  const ElectionResult({
    required this.role,
    required this.outcome,
    required this.peerCount,
    required this.ranking,
    required this.clockSkewDetected,
    this.leaderId,
    this.detail,
  });

  final ElectionRole role;
  final Outcome outcome;
  final int peerCount;
  final List<PeerRank> ranking;
  final bool clockSkewDetected;
  final String? leaderId;
  final String? detail;

  String get roleWire => switch (role) {
        ElectionRole.solo => 'SOLO',
        ElectionRole.leader => 'LEADER',
        ElectionRole.follower => 'FOLLOWER',
        ElectionRole.promoted => 'PROMOTED',
        ElectionRole.yielded => 'FOLLOWER',
      };
}
