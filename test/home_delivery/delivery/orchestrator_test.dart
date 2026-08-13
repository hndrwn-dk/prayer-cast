import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/common/scheduler.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';
import 'package:prayer_cast/home_delivery/coordination/election_schedule.dart';
import 'package:prayer_cast/home_delivery/coordination/peer_registry.dart';
import 'package:prayer_cast/home_delivery/coordination/session_id.dart';
import 'package:prayer_cast/home_delivery/coordination/unicast_transport.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_orchestrator.dart';
import 'package:prayer_cast/home_delivery/delivery/interface_selector.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_log_dao.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';
import 'package:prayer_cast/home_delivery/presence/presence_schedule.dart';
import 'package:prayer_cast/home_delivery/presence/presence_service.dart';
import 'package:prayer_cast/home_delivery/presence/presence_state.dart';

import '../presence/fake_mdns_browser.dart';
import 'cast_client_test.dart';

final class _LanIfaces implements NetworkInterfaceSource {
  @override
  Future<List<NetworkIface>> listIPv4() async => [
        NetworkIface(
          name: 'wlan0',
          address: InternetAddress('192.168.1.20'),
          netmask: InternetAddress('255.255.255.0'),
        ),
      ];
}

final class _VpnOnly implements NetworkInterfaceSource {
  @override
  Future<List<NetworkIface>> listIPv4() async => [
        NetworkIface(
          name: 'tun0',
          address: InternetAddress('10.8.0.2'),
          netmask: InternetAddress('255.255.255.0'),
        ),
      ];
}

void main() {
  late DateTime t;
  late ControllableScheduler scheduler;
  late DeliveryDatabase db;
  late DeliveryLogDao dao;
  late MemoryFingerprintStore store;
  late Set<String> homeHashes;
  late FakeMdnsBrowser browser;
  late FakeCastPlatform castPlatform;
  late InMemoryUnicastNetwork network;
  late InMemoryDiscoveryMesh mesh;
  late InMemoryAdzanDiscovery discovery;
  late InMemoryUnicastTransport transport;

  const castId = 'cast-home-1';
  const salt = 'testsalt';

  setUp(() {
    t = DateTime.utc(2026, 8, 10, 19, 2);
    scheduler = ControllableScheduler(
      ElectionSchedule.at(t, ElectionSchedule.claimStart),
    );
    db = DeliveryDatabase.memory();
    dao = DeliveryLogDao(db);

    homeHashes = {
      LanFingerprint.hashInstanceId(salt, castId),
      LanFingerprint.hashInstanceId(salt, 'Air@_airplay._tcp'),
      LanFingerprint.hashInstanceId(salt, 'HP@_printer._tcp'),
    };
    store = MemoryFingerprintStore(
      salt: salt,
      hashes: homeHashes,
      homeCastId: castId,
      electionSecret: 'test-household-election-secret',
    );

    browser = FakeMdnsBrowser([
      [
        const DiscoveredService(
          instanceName: 'Kitchen',
          serviceType: '_googlecast._tcp',
          txt: {'id': castId},
        ),
      ],
    ]);

    castPlatform = FakeCastPlatform(
      devices: [
        CastReceiver(
          deviceId: castId,
          friendlyName: 'Kitchen Nest',
          host: InternetAddress('192.168.1.50'),
        ),
      ],
    );

    network = InMemoryUnicastNetwork();
    mesh = InMemoryDiscoveryMesh();
    discovery = InMemoryAdzanDiscovery(mesh);
    transport = network.create();
    discovery.endpoint = transport.localEndpoint;
  });

  tearDown(() async {
    await transport.close();
    await db.close();
  });

  String homeFp() => LanFingerprint.shortHash(homeHashes);

  String sessionId() => SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: t.millisecondsSinceEpoch,
        homeFingerprintShort: homeFp(),
      );

  DeliveryOrchestrator buildOrchestrator({
    PresenceService? presence,
    NetworkInterfaceSource? ifaces,
    FakeCastPlatform? platform,
  }) {
    return DeliveryOrchestrator(
      presence: presence ??
          PresenceService(
            browser: browser,
            store: store,
            clock: FakeClock(scheduler.now()),
          ),
      fingerprintStore: store,
      identity: DeviceIdentity(
        store: MemoryDeviceIdStore('solo-device-0001'),
      ),
      discovery: discovery,
      transport: transport,
      castClient: CastClient(platform: platform ?? castPlatform),
      interfaces: InterfaceSelector(source: ifaces ?? _LanIfaces()),
      logDao: dao,
      scheduler: scheduler,
    );
  }

  DeliveryRequest request({DateTime? firedAt}) => DeliveryRequest(
        prayerName: 'maghrib',
        scheduledAzan: t,
        voiceId: 'makkah',
        audioBytes: Uint8List.fromList(List<int>.filled(64, 1)),
        homeCastDeviceId: castId,
        playbackVolume: 0.7,
        deviceConditions: const DeviceConditions(
          formFactor: DeviceFormFactor.phone,
          isPluggedIn: true,
          isScreenOn: true,
          batteryPercent: 80,
          batterySaverActive: false,
          clockSkewDetected: false,
        ),
        // Default: on-time wake at T−120 (not claim-start "now").
        firedAt: firedAt ??
            PresenceSchedule.at(t, PresenceSchedule.scanOffset),
      );

  Future<void> pumpThroughAzan() async {
    await scheduler.pumpUntil(t.add(const Duration(seconds: 1)));
  }

  group('DeliveryOrchestrator', () {
    test('solo HOME → PLAYED and one delivery_log row', () async {
      final orch = buildOrchestrator();
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;

      expect(result.outcome, Outcome.played);
      expect(result.role, 'SOLO');
      expect(castPlatform.loadedContentId, isNotNull);
      expect(castPlatform.lastSetVolume, 0.7);

      final rows = await dao.latest();
      expect(rows, hasLength(1));
      expect(rows.single.outcome, Outcome.played.code);
      expect(rows.single.role, 'SOLO');
      expect(rows.single.presenceState, 'HOME');
    });

    PresenceService awayPresence() {
      final emptyBrowser = FakeMdnsBrowser(const []);
      final awayStore = MemoryFingerprintStore(
        salt: salt,
        hashes: homeHashes,
        homeCastId: 'never-matches',
      );
      final clock = FakeClock(scheduler.now());
      final presence = PresenceService(
        browser: emptyBrowser,
        store: awayStore,
        clock: clock,
      );
      presence.applyScanResult(PresenceScanResult.notDetected());
      clock.advance(const Duration(seconds: 90));
      presence.applyScanResult(PresenceScanResult.notDetected());
      expect(presence.state, PresenceState.away);
      return presence;
    }

    test('AWAY → SUPPRESSED_AWAY, no cast', () async {
      final orch = buildOrchestrator(presence: awayPresence());
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.suppressedAway);
      expect(castPlatform.loadedContentId, isNull);
      expect((await dao.latest()).single.outcome, Outcome.suppressedAway.code);
    });

    test('§8 Both phones away → two SUPPRESSED_AWAY, zero casts', () async {
      // Each device runs its own orchestrator + log; neither casts.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      });
      final db2 = DeliveryDatabase.memory();
      addTearDown(db2.close);
      final dao2 = DeliveryLogDao(db2);

      final orch1 = buildOrchestrator(presence: awayPresence());
      final orch2 = DeliveryOrchestrator(
        presence: awayPresence(),
        fingerprintStore: store,
        identity: DeviceIdentity(
          store: MemoryDeviceIdStore('away-device-0002'),
        ),
        discovery: InMemoryAdzanDiscovery(mesh),
        transport: network.create(),
        castClient: CastClient(platform: castPlatform),
        interfaces: InterfaceSelector(source: _LanIfaces()),
        logDao: dao2,
        scheduler: scheduler,
      );

      final f1 = orch1.run(request());
      final f2 = orch2.run(request());
      await pumpThroughAzan();
      expect((await f1).outcome, Outcome.suppressedAway);
      expect((await f2).outcome, Outcome.suppressedAway);
      expect(castPlatform.loadedContentId, isNull);
      expect((await dao.latest()).single.outcome, Outcome.suppressedAway.code);
      expect((await dao2.latest()).single.outcome, Outcome.suppressedAway.code);
    });

    test('§8 Airplane mode at T−60 s → SUPPRESSED_AWAY (no crash/retry)',
        () async {
      // Empty browse = no Cast / fingerprint signal, same as radio off.
      final orch = buildOrchestrator(presence: awayPresence());
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.suppressedAway);
      expect(castPlatform.loadCallCount, 0);
    });

    test('§8 Speaker unplugged → FAILED_NO_TARGET, no crash, no retry',
        () async {
      final platform = FakeCastPlatform(devices: []);
      final orch = buildOrchestrator(platform: platform);
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.failedNoTarget);
      expect(platform.loadCallCount, 0);
      expect((await dao.latest()), hasLength(1));
    });

    test('alarm >60s after wake (T−120) → FAILED_ALARM_MISSED', () async {
      final orch = buildOrchestrator();
      final wakeAt = PresenceSchedule.at(t, PresenceSchedule.scanOffset);
      final result = await orch.run(
        request(firedAt: wakeAt.add(const Duration(seconds: 90))),
      );
      expect(result.outcome, Outcome.failedAlarmMissed);
      expect(castPlatform.loadedContentId, isNull);
    });

    test(
      'fire at T−30 (90s after wake) → FAILED_ALARM_MISSED, no solo cast',
      () async {
        // Concrete double-cast trigger before the fix: claim window is already
        // closed at T−22, so a late peer with empty CLAIMs took SOLO and
        // loadMedia while the on-time leader was preparing.
        final orch = buildOrchestrator();
        final result = await orch.run(
          request(firedAt: t.subtract(const Duration(seconds: 30))),
        );
        expect(result.outcome, Outcome.failedAlarmMissed);
        expect(castPlatform.loadCallCount, 0);
      },
    );

    test('fire 20s after wake is still eligible for delivery', () async {
      final orch = buildOrchestrator();
      final wakeAt = PresenceSchedule.at(t, PresenceSchedule.scanOffset);
      // Scheduler must be at/after firedAt for election waits to make sense.
      scheduler.advanceTo(wakeAt.add(const Duration(seconds: 20)));
      final future = orch.run(
        request(firedAt: wakeAt.add(const Duration(seconds: 20))),
      );
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.played);
    });

    test('VPN-only interfaces → FAILED_NO_ROUTE', () async {
      final orch = buildOrchestrator(ifaces: _VpnOnly());
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.failedNoRoute);
    });

    test('already playing → SUPPRESSED_ALREADY_PLAYING', () async {
      final contentId = CastClient.contentIdFor(
        sessionId: sessionId(),
        voiceId: 'makkah',
      );
      final platform = FakeCastPlatform(
        devices: [
          CastReceiver(
            deviceId: castId,
            friendlyName: 'Kitchen Nest',
            host: InternetAddress('192.168.1.50'),
          ),
        ],
        alreadyPlayingContentId: contentId,
      );
      final orch = buildOrchestrator(platform: platform);
      final future = orch.run(request());
      await pumpThroughAzan();
      final result = await future;
      expect(result.outcome, Outcome.suppressedAlreadyPlaying);
    });

    test(
      'MediaServer path token is never equal to sessionId for a delivery',
      () async {
        final orch = buildOrchestrator();
        final sid = sessionId();
        final future = orch.run(request());
        await pumpThroughAzan();
        final result = await future;

        expect(result.outcome, Outcome.played);
        expect(result.sessionId, sid);
        // contentId stays deterministic and session-scoped (§4.8).
        expect(
          castPlatform.loadedContentId,
          CastClient.contentIdFor(sessionId: sid, voiceId: 'makkah'),
        );
        final url = castPlatform.loadedUrl;
        expect(url, isNotNull);
        // /azan/{pathToken}/{voiceId}.mp3 — pathToken must not be sessionId.
        final segments = url!.pathSegments;
        expect(segments.length, 3);
        expect(segments[0], 'azan');
        expect(segments[2], 'makkah.mp3');
        final pathToken = segments[1];
        expect(pathToken, isNot(equals(sid)));
        expect(pathToken.length, greaterThanOrEqualTo(16));
      },
    );
  });
}
