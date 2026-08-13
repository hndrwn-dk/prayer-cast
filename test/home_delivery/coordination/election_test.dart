import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/scheduler.dart';
import 'package:prayer_cast/home_delivery/coordination/election.dart';
import 'package:prayer_cast/home_delivery/coordination/election_auth.dart';
import 'package:prayer_cast/home_delivery/coordination/election_message.dart';
import 'package:prayer_cast/home_delivery/coordination/election_schedule.dart';
import 'package:prayer_cast/home_delivery/coordination/peer_registry.dart';
import 'package:prayer_cast/home_delivery/coordination/session_id.dart';
import 'package:prayer_cast/home_delivery/coordination/unicast_transport.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';

import 'fake_peers.dart';

void main() {
  late DateTime T;
  late ControllableScheduler scheduler;
  const fp = 'abcd1234';

  setUp(() {
    T = DateTime.utc(2026, 8, 10, 19, 2);
    scheduler = ControllableScheduler(
      ElectionSchedule.at(T, ElectionSchedule.claimStart),
    );
  });

  Future<void> pumpTo(DateTime target) => scheduler.pumpUntil(target);

  group('§8 matrix — coordination', () {
    test('Solo phone, speaker present → SOLO / PLAYED, no election delay',
        () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final phone = home.addPeer(deviceId: 'solo-phone-0001', priority: 40);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final future = phone.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      // Solo decides at T−22 and casts at T+0 — must not wait for failover.
      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(T);
      await pumpTo(T.add(const Duration(seconds: 1)));

      final result = await future;
      expect(result.role, ElectionRole.solo);
      expect(result.outcome, Outcome.played);
      expect(result.peerCount, 0);
      // Finished at T+0, not T+4 failover.
      expect(scheduler.now().isBefore(T.add(const Duration(seconds: 4))), isTrue);
    });

    test('Two phones, both home → exactly one PLAYED, one SUPPRESSED_NOT_LEADER',
        () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final high = home.addPeer(deviceId: 'aaa-high-prio', priority: 40);
      final low = home.addPeer(deviceId: 'zzz-low-prio', priority: 25);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final fHigh = high.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );
      final fLow = low.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(T);
      await pumpTo(T.add(const Duration(seconds: 2)));

      final rHigh = await fHigh;
      final rLow = await fLow;

      expect(rHigh.outcome, Outcome.played);
      expect(rHigh.role, ElectionRole.leader);
      expect(rLow.outcome, Outcome.suppressedNotLeader);
      expect(rLow.role, ElectionRole.follower);
    });

    test('Leader killed at T−10 s → rank-2 promotes, PLAYED at ~T+4 s', () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
      final backup = home.addPeer(deviceId: 'bbb-backup', priority: 25);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final fLeader = leader.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
        onLead: () async {
          fail('killed leader must not cast');
        },
      );
      final fBackup = backup.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.leadEnd));

      // Kill leader during prepare (T−10).
      await pumpTo(T.subtract(const Duration(seconds: 10)));
      await leader.election!.cancel();
      await fLeader;

      await pumpTo(T.add(const Duration(seconds: 4)));
      await pumpTo(T.add(const Duration(seconds: 5)));

      final rBackup = await fBackup;
      expect(rBackup.role, ElectionRole.promoted);
      expect(rBackup.outcome, Outcome.played);
      expect(
        scheduler.now().isBefore(T.add(const Duration(seconds: 8))),
        isTrue,
      );
    });

    test('Leader Wi-Fi drops at T−1 s (YIELD) → immediate promotion', () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
      final backup = home.addPeer(deviceId: 'bbb-backup', priority: 25);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final fLeader = leader.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );
      final fBackup = backup.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.leadEnd));
      await pumpTo(T.subtract(const Duration(seconds: 1)));

      await leader.election!.yieldLeadership('wifi dropped');
      await pumpTo(T.subtract(const Duration(milliseconds: 500)));
      await pumpTo(T);
      await pumpTo(T.add(const Duration(seconds: 1)));

      final rLeader = await fLeader;
      final rBackup = await fBackup;

      expect(rLeader.role, ElectionRole.yielded);
      expect(rBackup.role, ElectionRole.promoted);
      expect(rBackup.outcome, Outcome.played);
      // Immediate promotion — must not wait until T+4.
      expect(
        scheduler.now().isBefore(T.add(const Duration(seconds: 4))),
        isTrue,
      );
    });

    test('Phone clock 5 min fast → CLOCK_SKEW, does not lead', () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      // Fast phone has higher base priority but skewed clock.
      final fast = home.addPeer(
        deviceId: 'zzz-fast-clock',
        priority: 40,
        clockOffset: const Duration(minutes: 5),
      );
      final sane = home.addPeer(deviceId: 'aaa-sane-clock', priority: 25);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final fFast = fast.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );
      final fSane = sane.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(T);
      await pumpTo(T.add(const Duration(seconds: 2)));

      final rFast = await fFast;
      final rSane = await fSane;

      expect(rFast.clockSkewDetected, isTrue);
      expect(rSane.clockSkewDetected, isTrue);
      // Two-device tie-break: lower deviceId leads (aaa < zzz).
      expect(rSane.outcome, Outcome.played);
      expect(rFast.outcome, Outcome.suppressedNotLeader);
    });

    test('Two houses, same SSID name → different sessionId, no cross-talk',
        () async {
      final houseA = FakeHousehold(fingerprintShort: 'aaaaaaaa');
      final houseB = FakeHousehold(fingerprintShort: 'bbbbbbbb');
      addTearDown(houseA.dispose);
      addTearDown(houseB.dispose);

      // Share one unicast network so datagrams *could* cross if sid ignored.
      final sharedNet = InMemoryUnicastNetwork();
      final meshA = InMemoryDiscoveryMesh();
      final meshB = InMemoryDiscoveryMesh();

      final a = FakePeer(
        deviceId: 'house-a-phone',
        priority: 40,
        fingerprintShort: 'aaaaaaaa',
        network: sharedNet,
        mesh: meshA,
      );
      final b = FakePeer(
        deviceId: 'house-b-phone',
        priority: 40,
        fingerprintShort: 'bbbbbbbb',
        network: sharedNet,
        mesh: meshB,
      );
      // Manually register endpoints so unicast could reach the other house.
      a.discovery.endpoint = a.transport.localEndpoint;
      b.discovery.endpoint = b.transport.localEndpoint;
      await a.startAdvertising();
      await b.startAdvertising();
      // Inject each other as endpoints without matching fingerprint peers.
      // (homePeers filters fp — they won't claim each other via registry.)
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      final sidA = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: 'aaaaaaaa',
      );
      final sidB = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: 'bbbbbbbb',
      );
      expect(sidA, isNot(equals(sidB)));

      final fA = a.runElection(
        sessionId: sidA,
        scheduledAzan: T,
        scheduler: scheduler,
      );
      final fB = b.runElection(
        sessionId: sidB,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
      await pumpTo(T);
      await pumpTo(T.add(const Duration(seconds: 1)));

      final rA = await fA;
      final rB = await fB;
      expect(rA.role, ElectionRole.solo);
      expect(rB.role, ElectionRole.solo);
      expect(rA.outcome, Outcome.played);
      expect(rB.outcome, Outcome.played);
    });

    test('One phone home, one away → home phone SOLO', () async {
      // Away phone simply does not join the election (orchestrator gates on
      // presence). Home phone sees zero claimants → solo.
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final homePhone = home.addPeer(deviceId: 'home-phone', priority: 40);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final future = homePhone.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(T.add(const Duration(seconds: 1)));
      final result = await future;
      expect(result.role, ElectionRole.solo);
      expect(result.outcome, Outcome.played);
    });

    test(
      'Rank-2 promotion is slow (blocked in onPrepare past T+8) → rank-3 '
      'hears rank-2\'s LEAD and delays, no double PLAYING',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
        final rank2 = home.addPeer(deviceId: 'bbb-rank2', priority: 25);
        final rank3 = home.addPeer(deviceId: 'ccc-rank3', priority: 10);
        await home.startAll();

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        final fLeader = leader.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onLead: () async {
            fail('killed leader must not cast');
          },
        );
        final fRank2 = rank2.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onPrepare: () =>
              scheduler.waitUntil(T.add(const Duration(seconds: 10))),
        );
        final fRank3 = rank3.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.leadEnd));
        await pumpTo(T.subtract(const Duration(seconds: 10)));
        await leader.election!.cancel();
        await fLeader;

        var rank3Done = false;
        unawaited(fRank3.then((_) => rank3Done = true));

        // Rank-2 promotes at T+4, broadcasts LEAD; onPrepare still blocked.
        await pumpTo(T.add(const Duration(seconds: 5)));
        // Without LEAD-delay, rank-3 would promote at T+8.
        await pumpTo(T.add(const Duration(seconds: 9)));
        expect(rank3Done, isFalse);

        await pumpTo(T.add(const Duration(seconds: 11)));
        final r2 = await fRank2;
        final r3 = await fRank3;
        expect(r2.role, ElectionRole.promoted);
        expect(r2.outcome, Outcome.played);
        expect(r3.role, ElectionRole.follower);
        expect(r3.outcome, Outcome.suppressedNotLeader);
      },
    );

    test(
      'Rank-2\'s LEAD broadcast is lost (simulate one dropped packet) → '
      'the second broadcast is enough for rank-3 to stand down',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
        final rank2 = home.addPeer(deviceId: 'bbb-rank2', priority: 25);
        final rank3 = home.addPeer(deviceId: 'ccc-rank3', priority: 10);
        await home.startAll();

        var droppedLeadToRank3 = false;
        home.network.shouldDrop = (from, to, bytes) {
          if (to.port != rank3.transport.localEndpoint.port) return false;
          final message = rank3.auth.decodeVerified(bytes);
          if (message is LeadMessage &&
              message.deviceId == rank2.deviceId &&
              !droppedLeadToRank3) {
            droppedLeadToRank3 = true;
            return true;
          }
          return false;
        };

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        final fLeader = leader.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onLead: () async {
            fail('killed leader must not cast');
          },
        );
        final fRank2 = rank2.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onPrepare: () =>
              scheduler.waitUntil(T.add(const Duration(seconds: 10))),
        );
        final fRank3 = rank3.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        await pumpTo(T.subtract(const Duration(seconds: 10)));
        await leader.election!.cancel();
        await fLeader;

        var rank3Done = false;
        unawaited(fRank3.then((_) => rank3Done = true));

        await pumpTo(T.add(const Duration(seconds: 5)));
        expect(droppedLeadToRank3, isTrue);
        await pumpTo(T.add(const Duration(seconds: 9)));
        expect(rank3Done, isFalse);

        await pumpTo(T.add(const Duration(seconds: 11)));
        final r2 = await fRank2;
        final r3 = await fRank3;
        expect(r2.outcome, Outcome.played);
        expect(r3.outcome, Outcome.suppressedNotLeader);
        expect(r3.role, ElectionRole.follower);
      },
    );

    test(
      'Stray LEAD from a device outranked at claim time is ignored, '
      'rank-3 still promotes on schedule',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
        final rank2 = home.addPeer(deviceId: 'bbb-rank2', priority: 25);
        final rank3 = home.addPeer(deviceId: 'ccc-rank3', priority: 15);
        final rank4 = home.addPeer(deviceId: 'ddd-rank4', priority: 10);
        await home.startAll();

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        final fLeader = leader.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onLead: () async {
            fail('killed leader must not cast');
          },
        );
        final fRank2 = rank2.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
          onLead: () async {
            fail('cancelled rank-2 must not cast');
          },
        );
        final fRank3 = rank3.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );
        final fRank4 = rank4.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        await pumpTo(T.subtract(const Duration(seconds: 10)));
        await leader.election!.cancel();
        await fLeader;
        // Rank-2 never promotes — leave rank-3 as next failover at T+8.
        await rank2.election!.cancel();
        await fRank2;

        // Stray LEAD from outranked rank-4 just before rank-3's failover.
        await pumpTo(T.add(const Duration(seconds: 7)));
        await rank4.transport.send(
          rank3.transport.localEndpoint,
          rank4.auth.encodeSigned(
            LeadMessage(sessionId: sessionId, deviceId: rank4.deviceId),
          ),
        );

        await pumpTo(T.add(const Duration(seconds: 8)));
        await pumpTo(T.add(const Duration(seconds: 10)));

        final r3 = await fRank3;
        expect(r3.role, ElectionRole.promoted);
        expect(r3.outcome, Outcome.played);
        // Promoted before the extended T+12 slot would have been.
        expect(
          scheduler.now().isBefore(T.add(const Duration(seconds: 12))),
          isTrue,
        );

        await pumpTo(T.add(const Duration(seconds: 13)));
        final r4 = await fRank4;
        expect(r4.outcome, Outcome.suppressedNotLeader);
      },
    );

    test(
      'Rank-5 with no PLAYING gives up at T+30 — does not spin forever',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        // Lexicographic deviceIds so ranking order is stable with equal-ish pri.
        final peers = [
          for (var i = 1; i <= 5; i++)
            home.addPeer(
              deviceId: 'phone-$i',
              priority: 40 - i, // phone-1 highest rank
            ),
        ];
        await home.startAll();

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        final futures = [
          for (final peer in peers)
            peer.runElection(
              sessionId: sessionId,
              scheduledAzan: T,
              scheduler: scheduler,
            ),
        ];

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        // Cancel ranks 1–4 without PLAYING so rank-5 must rely on give-up.
        for (var i = 0; i < 4; i++) {
          await peers[i].election!.cancel();
          await futures[i];
        }

        await pumpTo(
          ElectionSchedule.at(T, ElectionSchedule.followerGiveUp)
              .add(const Duration(seconds: 1)),
        );

        final rank5 = await futures[4];
        expect(rank5.role, ElectionRole.follower);
        expect(rank5.outcome, Outcome.suppressedNotLeader);
        expect(rank5.detail, contains('follower give-up'));
      },
    );

    test(
      'Forged high-pri CLAIM + PLAYING without HMAC cannot suppress cast',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        final phone = home.addPeer(deviceId: 'home-phone', priority: 40);
        await home.startAll();

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        // Attacker on the LAN: knows sid from fp, injects unsigned CLAIM/PLAYING.
        final attacker = home.network.create();
        addTearDown(attacker.close);

        final future = phone.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimStart));
        await attacker.send(
          phone.transport.localEndpoint,
          ClaimMessage(
            sessionId: sessionId,
            deviceId: 'attacker-high-pri',
            priority: 100,
            nowEpochMs: scheduler.now().millisecondsSinceEpoch,
          ).encode(),
        );
        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        await attacker.send(
          phone.transport.localEndpoint,
          PlayingMessage(
            sessionId: sessionId,
            deviceId: 'attacker-high-pri',
          ).encode(),
        );

        await pumpTo(T.add(const Duration(seconds: 1)));
        final result = await future;
        // Solo: forged packets dropped (no MAC) — still casts.
        expect(result.role, ElectionRole.solo);
        expect(result.outcome, Outcome.played);
      },
    );

    test(
      'PLAYING from a device that never claimed is ignored',
      () async {
        final home = FakeHousehold(fingerprintShort: fp);
        addTearDown(home.dispose);
        final leader = home.addPeer(deviceId: 'aaa-leader', priority: 40);
        final follower = home.addPeer(deviceId: 'bbb-follower', priority: 25);
        await home.startAll();

        final sessionId = SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: T.millisecondsSinceEpoch,
          homeFingerprintShort: fp,
        );

        final fLeader = leader.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );
        final fFollower = follower.runElection(
          sessionId: sessionId,
          scheduledAzan: T,
          scheduler: scheduler,
        );

        await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimEnd));
        // Signed PLAYING from a stranger that never claimed — must not suppress.
        final stranger = home.network.create();
        addTearDown(stranger.close);
        await stranger.send(
          follower.transport.localEndpoint,
          follower.auth.encodeSigned(
            PlayingMessage(
              sessionId: sessionId,
              deviceId: 'zzz-stranger',
            ),
          ),
        );

        await pumpTo(T.add(const Duration(seconds: 2)));
        final rLeader = await fLeader;
        final rFollower = await fFollower;
        expect(rLeader.outcome, Outcome.played);
        expect(rFollower.outcome, Outcome.suppressedNotLeader);
        expect(rFollower.role, ElectionRole.follower);
      },
    );

    test('CLAIM with priority outside 0–100 is rejected', () async {
      final home = FakeHousehold(fingerprintShort: fp);
      addTearDown(home.dispose);
      final phone = home.addPeer(deviceId: 'home-phone', priority: 40);
      await home.startAll();

      final sessionId = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: T.millisecondsSinceEpoch,
        homeFingerprintShort: fp,
      );

      final future = phone.runElection(
        sessionId: sessionId,
        scheduledAzan: T,
        scheduler: scheduler,
      );

      await pumpTo(ElectionSchedule.at(T, ElectionSchedule.claimStart));
      final attacker = home.network.create();
      addTearDown(attacker.close);

      final evilBody = <String, Object?>{
        't': 'CLAIM',
        'sid': sessionId,
        'id': 'evil-overpri',
        'pri': 250,
        'now': scheduler.now().millisecondsSinceEpoch,
      };
      final canonical = ElectionAuth.canonicalPayload(evilBody);
      final digest = Hmac(sha256, utf8.encode(kTestElectionSecret))
          .convert(utf8.encode(canonical));
      evilBody['mac'] =
          digest.toString().substring(0, ElectionAuth.macHexLength);
      await attacker.send(
        phone.transport.localEndpoint,
        utf8.encode(jsonEncode(evilBody)),
      );

      await pumpTo(T.add(const Duration(seconds: 1)));
      final result = await future;
      expect(result.role, ElectionRole.solo);
      expect(result.outcome, Outcome.played);
    });
  });

  group('election messages', () {
    test('round-trip CLAIM/LEAD/PLAYING/YIELD JSON', () {
      final claim = ClaimMessage(
        sessionId: 'abc123def4567890',
        deviceId: 'dev-1',
        priority: 40,
        nowEpochMs: 1000,
      );
      expect(ElectionMessage.decode(claim.encode()), isA<ClaimMessage>());
      expect(
        ElectionMessage.decode(
          const LeadMessage(sessionId: 'abc123def4567890', deviceId: 'dev-1')
              .encode(),
        ),
        isA<LeadMessage>(),
      );
      expect(
        ElectionMessage.decode(
          const PlayingMessage(
            sessionId: 'abc123def4567890',
            deviceId: 'dev-1',
          ).encode(),
        ),
        isA<PlayingMessage>(),
      );
      expect(
        ElectionMessage.decode(
          const YieldMessage(
            sessionId: 'abc123def4567890',
            deviceId: 'dev-1',
            reason: 'battery',
          ).encode(),
        ),
        isA<YieldMessage>(),
      );
    });

    test('CLAIM priority outside 0–100 fails parse', () {
      expect(
        () => ClaimMessage.fromJson({
          't': 'CLAIM',
          'sid': 'abc123def4567890',
          'id': 'dev-1',
          'pri': 101,
          'now': 1,
        }),
        throwsA(isA<ElectionProtocolFailure>()),
      );
      expect(
        () => ClaimMessage.fromJson({
          't': 'CLAIM',
          'sid': 'abc123def4567890',
          'id': 'dev-1',
          'pri': -1,
          'now': 1,
        }),
        throwsA(isA<ElectionProtocolFailure>()),
      );
    });

    test('HMAC round-trip accepts valid MAC and rejects tamper', () {
      final auth = ElectionAuth(kTestElectionSecret);
      final signed = auth.encodeSigned(
        const ClaimMessage(
          sessionId: 'abc123def4567890',
          deviceId: 'dev-1',
          priority: 40,
          nowEpochMs: 1000,
        ),
      );
      expect(auth.decodeVerified(signed), isA<ClaimMessage>());

      final map = jsonDecode(utf8.decode(signed)) as Map<String, dynamic>;
      map['pri'] = 99;
      expect(
        () => auth.decodeVerified(utf8.encode(jsonEncode(map))),
        throwsA(isA<ElectionProtocolFailure>()),
      );
    });
  });
}
