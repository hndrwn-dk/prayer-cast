import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../common/logger.dart';
import '../common/scheduler.dart';
import '../coordination/device_identity.dart';
import '../coordination/election.dart';
import '../coordination/election_message.dart';
import '../coordination/peer_registry.dart';
import '../coordination/session_id.dart';
import '../coordination/unicast_transport.dart';
import '../logging/delivery_log_dao.dart';
import '../logging/outcome.dart';
import '../presence/fingerprint_store.dart';
import '../presence/lan_fingerprint.dart';
import '../presence/presence_schedule.dart';
import '../presence/presence_service.dart';
import '../presence/presence_state.dart';
import 'cast_client.dart';
import 'delivery_timing.dart';
import 'interface_selector.dart';
import 'media_server.dart';

/// Inputs for one azan delivery attempt.
final class DeliveryRequest {
  const DeliveryRequest({
    required this.prayerName,
    required this.scheduledAzan,
    required this.voiceId,
    required this.audioBytes,
    required this.homeCastDeviceId,
    required this.playbackVolume,
    required this.deviceConditions,
    this.contentType = 'audio/mpeg',
    this.mediaExtension = 'mp3',
    this.firedAt,
  });

  final String prayerName;
  final DateTime scheduledAzan;
  final String voiceId;
  final Uint8List audioBytes;
  final String contentType;
  final String mediaExtension;
  final String homeCastDeviceId;
  final double playbackVolume;
  final DeviceConditions deviceConditions;

  /// When the alarm actually fired. Defaults to scheduler.now() if null.
  final DateTime? firedAt;
}

/// Ties presence → election → cast and writes one delivery_log row (§7).
///
/// WHY: The only module allowed to know about all three subsystems. Presence
/// and coordination must not import delivery (dependency rule §7) so they stay
/// testable without Cast/HTTP and cannot accidentally start playback.
final class DeliveryOrchestrator {
  DeliveryOrchestrator({
    required PresenceService presence,
    required FingerprintStore fingerprintStore,
    required DeviceIdentity identity,
    required AdzanDiscovery discovery,
    required UnicastTransport transport,
    required CastClient castClient,
    required InterfaceSelector interfaces,
    required DeliveryLogDao logDao,
    required Scheduler scheduler,
    HomeDeliveryLogger logger = const SilentLogger(),
    Duration playbackConfirmTimeout = const Duration(seconds: 20),
  })  : _presence = presence,
        _fingerprintStore = fingerprintStore,
        _identity = identity,
        _discovery = discovery,
        _transport = transport,
        _cast = castClient,
        _interfaces = interfaces,
        _logDao = logDao,
        _scheduler = scheduler,
        _logger = logger,
        _playbackConfirmTimeout = playbackConfirmTimeout;

  /// Alarms more than this late *relative to the wake epoch* (T−120) are OEM
  /// battery kills (§6.2). Must not be measured against azan T — a wake that
  /// fires after the claim window would otherwise take the solo path and
  /// double-cast while another peer is already leading.
  static const Duration alarmMissedThreshold = Duration(seconds: 60);

  /// Media server lifetime cap after T. Match the working test button
  /// (6 min) — a full adhan is 4–5 min; 180s cut playback off.
  static const Duration mediaServerMaxLifetime = Duration(minutes: 6);

  final PresenceService _presence;
  final FingerprintStore _fingerprintStore;
  final DeviceIdentity _identity;
  final AdzanDiscovery _discovery;
  final UnicastTransport _transport;
  final CastClient _cast;
  final InterfaceSelector _interfaces;
  final DeliveryLogDao _logDao;
  final Scheduler _scheduler;
  final HomeDeliveryLogger _logger;

  /// How long onLead waits for PLAYING (or a media-server fetch) before
  /// treating loadMedia as a silent failure. Matches the manual test button.
  final Duration _playbackConfirmTimeout;

  MediaServer? _mediaServer;
  Timer? _mediaLifetimeTimer;

  /// Run one full delivery attempt for [request].
  Future<DeliveryAttemptResult> run(DeliveryRequest request) async {
    final firedAt = request.firedAt ?? _scheduler.now();
    final scheduled = request.scheduledAzan;
    final castId = await _fingerprintStore.readHomeCastIdResilient();
    final hashes = await _fingerprintStore.readHashes();
    // Household fp must match on every phone that saved the same speaker.
    // shortHash(hashes) is per-install (salted) and broke multi-phone election.
    final homeFp = (castId != null && castId.isNotEmpty)
        ? LanFingerprint.householdFingerprintShort(castId)
        : (hashes.isEmpty ? '00000000' : LanFingerprint.shortHash(hashes));

    final sessionId = SessionId.derive(
      prayerName: request.prayerName,
      scheduledEpochMs: scheduled.millisecondsSinceEpoch,
      homeFingerprintShort: homeFp,
    );

    // OEM battery killer: fired > 60s after the scheduled wake (T−120), not
    // after azan T. Wake is when AlarmManager was armed; measuring against T
    // allowed 61–179s of OEM delay to proceed into a post-claim solo cast.
    final wakeAt = PresenceSchedule.at(scheduled, PresenceSchedule.scanOffset);
    final wakeLateness = firedAt.difference(wakeAt);
    if (wakeLateness > alarmMissedThreshold) {
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: null,
        role: null,
        peerCount: null,
        outcome: Outcome.failedAlarmMissed,
        detail: 'fired ${wakeLateness.inSeconds}s after wake',
      );
    }

    // Dart start time, not native firedAt. pendingFire keeps the alarm's
    // firedAt; opening the app 50 minutes later must not Cast.
    final now = _scheduler.now();
    if (DeliveryTiming.isTooLate(scheduledAzan: scheduled, now: now)) {
      final late = now.difference(scheduled);
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: null,
        role: null,
        peerCount: null,
        outcome: Outcome.failedAlarmMissed,
        detail: 'dart started ${late.inSeconds}s after azan '
            '(grace ${DeliveryTiming.graceAfterAzan.inMinutes}m)',
      );
    }

    // Presence — §3.6: decide at T−90. Only AWAY suppresses. A cold-start
    // UNKNOWN after one miss is not away (Nest may still be on the LAN).
    final snapshot = await _resolvePresence(scheduled);
    if (snapshot.state == PresenceState.away) {
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: snapshot,
        role: null,
        peerCount: null,
        outcome: Outcome.suppressedAway,
        detail: 'presence=${snapshot.state.name}',
      );
    }

    // Load CastContext / MediaRouter during T-120..T-20 so GMS Dynamite
    // is not first touched at startSession (00:09 dry-run timed out there).
    unawaited(_cast.warmUp());

    final deviceId = await _identity.deviceId();
    final priority = _identity.priority(request.deviceConditions);
    final registry = PeerRegistry(
      discovery: _discovery,
      homeFingerprintShort: homeFp,
      logger: _logger,
    );

    await registry.start(
      deviceId: deviceId,
      priority: priority,
      state: PeerAdState.idle,
      udpPort: _transport.localEndpoint.port,
    );

    var sharedSecret = await _fingerprintStore.readElectionSecret();
    if (castId != null && castId.isNotEmpty) {
      final derived = LanFingerprint.householdElectionSecret(castId);
      if (sharedSecret != derived) {
        await _fingerprintStore.writeElectionSecret(derived);
        sharedSecret = derived;
      }
    }
    if (sharedSecret == null || sharedSecret.isEmpty) {
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: snapshot,
        role: null,
        peerCount: null,
        outcome: Outcome.failedLoadMedia,
        detail: 'missing election shared secret — complete home onboarding',
      );
    }

    final election = Election(
      sessionId: sessionId,
      deviceId: deviceId,
      basePriority: priority,
      scheduledAzan: scheduled,
      sharedSecret: sharedSecret,
      registry: registry,
      transport: _transport,
      scheduler: _scheduler,
      logger: _logger,
    );

    String? targetId;
    String? targetName;
    int? latencyMs;
    InternetAddress? advertisedHost;

    try {
      final electionResult = await election.run(
        onPrepare: () async {
          final receiver = await _cast.connectById(
            request.homeCastDeviceId,
            budget: const Duration(seconds: 20),
          );
          targetId = receiver.deviceId;
          targetName = receiver.friendlyName;
          advertisedHost = await _interfaces.selectFor(receiver.host);

          // pathToken defaults to a cryptographically random value inside
          // MediaServer — never reuse sessionId (derivable from public TXT fp).
          final server = MediaServer(
            audioBytes: request.audioBytes,
            voiceId: request.voiceId,
            contentType: request.contentType,
            fileExtension: request.mediaExtension,
            logger: _logger,
          );
          await server.start();
          _mediaServer = server;
          _armMediaLifetime(scheduled);

          await _cast.applyPlaybackVolume(request.playbackVolume);
        },
        onLead: () async {
          final server = _mediaServer;
          final host = advertisedHost;
          if (server == null || host == null || server.port == null) {
            throw CastLoadMediaFailure('Media server not prepared');
          }
          final contentId = CastClient.contentIdFor(
            sessionId: sessionId,
            voiceId: request.voiceId,
          );
          await _cast.assertNotAlreadyPlaying(contentId);
          // Subscribe before loadMedia — PLAYING may arrive synchronously
          // in tests, or seconds later on a real receiver.
          final playingOrDone = _cast.playbackEvents.firstWhere(
            (e) =>
                e == CastPlaybackEvent.playing ||
                e == CastPlaybackEvent.finished,
          );
          final failed = _cast.playbackEvents.firstWhere(
            (e) => e == CastPlaybackEvent.error,
          );
          // Re-apply volume after media client is ready (same as test button).
          await _cast.applyPlaybackVolume(request.playbackVolume);
          final loadStarted = _scheduler.now();
          final deadline = loadStarted.add(_playbackConfirmTimeout);
          Object? outcome;
          while (true) {
            await _cast.loadAdzan(
              contentId: contentId,
              contentUrl: server.mediaUri(host),
              contentType: request.contentType,
            );
            final now = _scheduler.now();
            if (!now.isBefore(deadline)) {
              outcome = 'timeout';
              break;
            }
            final retryAt = now.add(const Duration(seconds: 1));
            final waitUntil = retryAt.isBefore(deadline) ? retryAt : deadline;
            outcome = await Future.any<Object>([
              playingOrDone,
              failed,
              _scheduler.waitUntil(waitUntil).then<Object>((_) {
                if (server.hitCount > 0) return 'fetched';
                if (!_scheduler.now().isBefore(deadline)) return 'timeout';
                return 'retry';
              }),
            ]);
            if (outcome != 'retry') break;
            _logger.warn(
              'Retry loadMedia after 0 fetches (media client may not be ready)',
              tag: 'DeliveryOrchestrator',
            );
          }
          latencyMs =
              _scheduler.now().difference(loadStarted).inMilliseconds;
          if (outcome == CastPlaybackEvent.error) {
            throw CastLoadMediaFailure('receiver reported ERROR');
          }
          if ((outcome == 'timeout' || outcome == 'retry') &&
              server.hitCount == 0) {
            throw CastLoadMediaFailure(
              'no PLAYING within ${_playbackConfirmTimeout.inSeconds}s '
              'and speaker fetched 0 bytes',
            );
          }
        },
      );

      // Follower / suppressed paths: tear down any partial prepare.
      if (electionResult.outcome != Outcome.played) {
        await _teardownCastAndServer();
      } else {
        // Playback continues on the receiver. Keep HTTP up like the test
        // button (6 min). Do not endSession — that stops casting.
        unawaited(_watchPlaybackLifetime());
      }

      if (electionResult.clockSkewDetected &&
          electionResult.outcome == Outcome.played) {
        // Successful lead despite skew logging on a peer — still PLAYED.
      }

      // Log CLOCK_SKEW as detail when demoted; outcome already set by election.
      return await _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: snapshot,
        role: electionResult.roleWire,
        peerCount: electionResult.peerCount,
        outcome: electionResult.clockSkewDetected &&
                electionResult.role == ElectionRole.follower
            ? (electionResult.outcome == Outcome.suppressedNotLeader
                ? Outcome.suppressedNotLeader
                : electionResult.outcome)
            : electionResult.outcome,
        detail: electionResult.detail ??
            (electionResult.clockSkewDetected ? 'CLOCK_SKEW' : null),
        targetId: targetId,
        targetName: targetName,
        latencyMs: latencyMs,
        extraClockSkewLog: electionResult.clockSkewDetected &&
            electionResult.role != ElectionRole.follower,
      );
    } on OutcomeException catch (e) {
      await _teardownCastAndServer();
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: snapshot,
        role: null,
        peerCount: null,
        outcome: e.outcome,
        detail: e.toString(),
        targetId: targetId,
        targetName: targetName,
      );
    } catch (e, st) {
      _logger.error(
        'Delivery failed',
        tag: 'DeliveryOrchestrator',
        error: e,
        stackTrace: st,
      );
      await _teardownCastAndServer();
      return _finish(
        request: request,
        sessionId: sessionId,
        firedAt: firedAt,
        presence: snapshot,
        role: null,
        peerCount: null,
        outcome: Outcome.failedLoadMedia,
        detail: e.toString(),
        targetId: targetId,
        targetName: targetName,
      );
    } finally {
      await registry.stop();
    }
  }

  void _armMediaLifetime(DateTime scheduled) {
    _mediaLifetimeTimer?.cancel();
    final fromT = scheduled.add(mediaServerMaxLifetime);
    // Late Dart start (BAL delay) must still serve long enough for the
    // receiver to connect and GET — not tear down at a T+180 already past.
    final fromNow = _scheduler.now().add(mediaServerMaxLifetime);
    final deadline = fromT.isAfter(fromNow) ? fromT : fromNow;
    final remaining = deadline.difference(_scheduler.now());
    if (remaining <= Duration.zero) {
      unawaited(_teardownCastAndServer());
      return;
    }
    // Wall timer as a safety net; primary stop is playback event.
    _mediaLifetimeTimer = Timer(remaining, () {
      unawaited(_stopMediaServer());
    });
  }

  /// Scan now; if still UNKNOWN, retry until T−90. Never treat one miss as away.
  Future<PresenceSnapshot> _resolvePresence(DateTime scheduledAzan) async {
    var snapshot = await _presence.scan();
    if (snapshot.state == PresenceState.home ||
        snapshot.state == PresenceState.away) {
      return snapshot;
    }

    final decisionAt = PresenceSchedule.at(
      scheduledAzan,
      PresenceSchedule.decisionOffset,
    );
    while (_scheduler.now().isBefore(decisionAt)) {
      final nextTry = _scheduler.now().add(LanFingerprint.browseBudget);
      final waitUntil =
          nextTry.isBefore(decisionAt) ? nextTry : decisionAt;
      await _scheduler.waitUntil(waitUntil);
      snapshot = await _presence.scan();
      if (snapshot.state == PresenceState.home ||
          snapshot.state == PresenceState.away) {
        return snapshot;
      }
    }
    return snapshot;
  }

  Future<void> _watchPlaybackLifetime() async {
    try {
      await _cast.playbackEvents
          .firstWhere((e) => e == CastPlaybackEvent.finished)
          .timeout(mediaServerMaxLifetime);
    } catch (_) {
      // Timeout, IDLE-only devices, or stream closed — leave session up.
    }
    await _cast.restoreVolume();
    await _stopMediaServer();
  }

  Future<void> _stopMediaServer() async {
    _mediaLifetimeTimer?.cancel();
    _mediaLifetimeTimer = null;
    try {
      await _mediaServer?.stop();
    } catch (_) {}
    _mediaServer = null;
  }

  Future<void> _teardownCastAndServer({bool restoreVolume = true}) async {
    _mediaLifetimeTimer?.cancel();
    _mediaLifetimeTimer = null;
    try {
      await _cast.endSession(restoreVolumeFirst: restoreVolume);
    } catch (_) {}
    try {
      await _mediaServer?.stop();
    } catch (_) {}
    _mediaServer = null;
  }

  Future<DeliveryAttemptResult> _finish({
    required DeliveryRequest request,
    required String sessionId,
    required DateTime firedAt,
    required PresenceSnapshot? presence,
    required String? role,
    required int? peerCount,
    required Outcome outcome,
    String? detail,
    String? targetId,
    String? targetName,
    int? latencyMs,
    bool extraClockSkewLog = false,
  }) async {
    await _logDao.insertAttempt(
      sessionId: sessionId,
      prayer: request.prayerName,
      scheduledAtMs: request.scheduledAzan.millisecondsSinceEpoch,
      firedAtMs: firedAt.millisecondsSinceEpoch,
      presenceState: presence?.state.name.toUpperCase(),
      presenceSignal: _signalWire(presence?.signal),
      role: role,
      peerCount: peerCount,
      targetId: targetId,
      targetName: targetName,
      outcome: outcome,
      detail: detail,
      latencyMs: latencyMs,
    );

    if (extraClockSkewLog) {
      await _logDao.insertAttempt(
        sessionId: sessionId,
        prayer: request.prayerName,
        scheduledAtMs: request.scheduledAzan.millisecondsSinceEpoch,
        firedAtMs: firedAt.millisecondsSinceEpoch,
        presenceState: presence?.state.name.toUpperCase(),
        presenceSignal: _signalWire(presence?.signal),
        role: role,
        peerCount: peerCount,
        outcome: Outcome.clockSkew,
        detail: 'skew > 3s during election',
      );
    }

    return DeliveryAttemptResult(
      sessionId: sessionId,
      outcome: outcome,
      role: role,
      detail: detail,
    );
  }

  static String? _signalWire(PresenceSignal? signal) {
    if (signal == null) return null;
    return switch (signal) {
      PresenceSignal.a => 'A',
      PresenceSignal.b => 'B',
      PresenceSignal.c => 'C',
      PresenceSignal.d => 'D',
      PresenceSignal.none => 'NONE',
    };
  }
}

/// Result of [DeliveryOrchestrator.run] for the caller / tests.
final class DeliveryAttemptResult {
  const DeliveryAttemptResult({
    required this.sessionId,
    required this.outcome,
    required this.role,
    this.detail,
  });

  final String sessionId;
  final Outcome outcome;
  final String? role;
  final String? detail;
}
