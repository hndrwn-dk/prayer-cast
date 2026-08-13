import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';
import 'package:prayer_cast/home_delivery/presence/presence_schedule.dart';
import 'package:prayer_cast/home_delivery/presence/presence_service.dart';
import 'package:prayer_cast/home_delivery/presence/presence_state.dart';

import 'fake_mdns_browser.dart';

void main() {
  late FakeClock clock;
  late MemoryFingerprintStore store;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 8, 10, 12, 0, 0));
    store = MemoryFingerprintStore(
      salt: 'salt',
      homeCastId: 'home-cast-id',
    );
  });

  PresenceService buildService(FakeMdnsBrowser browser) {
    return PresenceService(
      browser: browser,
      store: store,
      clock: clock,
    );
  }

  group('hysteresis §3.4', () {
    test('transient single-scan failure must NOT flip to AWAY', () {
      final service = buildService(FakeMdnsBrowser(const []));
      // Establish HOME first.
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );
      expect(service.state, PresenceState.home);

      clock.advance(const Duration(seconds: 30));
      final snap = service.applyScanResult(
        PresenceScanResult.notDetected(detail: 'transient'),
      );

      expect(snap.state, PresenceState.home);
      expect(service.state, isNot(PresenceState.away));
    });

    test('two consecutive false scans spanning >= 90s flip HOME to AWAY', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );

      clock.advance(const Duration(seconds: 10));
      service.applyScanResult(PresenceScanResult.notDetected());
      expect(service.state, PresenceState.home);

      clock.advance(const Duration(seconds: 90));
      final snap = service.applyScanResult(PresenceScanResult.notDetected());

      expect(snap.state, PresenceState.away);
      expect(service.state, PresenceState.away);
      expect(service.lastSignal, PresenceSignal.none);
    });

    test('two false scans spanning < 90s must NOT flip to AWAY', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.b),
      );

      service.applyScanResult(PresenceScanResult.notDetected());
      clock.advance(const Duration(seconds: 60));
      service.applyScanResult(PresenceScanResult.notDetected());

      expect(service.state, PresenceState.home);

      // Third false once the streak spans >= 90s from the first.
      clock.advance(const Duration(seconds: 40));
      service.applyScanResult(PresenceScanResult.notDetected());
      expect(service.state, PresenceState.away);
    });

    test('UNKNOWN goes HOME on a single A or B true scan', () {
      final service = buildService(FakeMdnsBrowser(const []));
      expect(service.state, PresenceState.unknown);

      final snap = service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.b),
      );
      expect(snap.state, PresenceState.home);
      expect(snap.signal, PresenceSignal.b);
    });

    test('UNKNOWN needs two spaced false scans before AWAY', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(PresenceScanResult.notDetected());
      expect(service.state, PresenceState.unknown);

      clock.advance(const Duration(seconds: 100));
      service.applyScanResult(PresenceScanResult.notDetected());
      expect(service.state, PresenceState.away);
    });

    test('a true scan resets the false streak', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );
      service.applyScanResult(PresenceScanResult.notDetected());
      clock.advance(const Duration(seconds: 50));
      // Recovery — streak clears.
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );
      clock.advance(const Duration(seconds: 50));
      service.applyScanResult(PresenceScanResult.notDetected());
      // Only one false since reset; still HOME.
      expect(service.state, PresenceState.home);
    });

    test('AWAY returns to HOME on the next true scan', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(PresenceScanResult.notDetected());
      clock.advance(const Duration(seconds: 90));
      service.applyScanResult(PresenceScanResult.notDetected());
      expect(service.state, PresenceState.away);

      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );
      expect(service.state, PresenceState.home);
    });
  });

  group('scan() Signal A and B', () {
    test('Signal A: saved Cast id discoverable → HOME', () async {
      final browser = FakeMdnsBrowser([
        [
          const DiscoveredService(
            instanceName: 'Kitchen',
            serviceType: '_googlecast._tcp',
            txt: {'id': 'home-cast-id'},
          ),
        ],
      ]);
      final service = buildService(browser);

      final snap = await service.scan();
      expect(snap.state, PresenceState.home);
      expect(snap.signal, PresenceSignal.a);
    });

    test('Signal B: fingerprint match when Cast id absent', () async {
      store = MemoryFingerprintStore(
        salt: 'salt',
        hashes: {
          LanFingerprint.hashInstanceId('salt', 'cast-aaa'),
          LanFingerprint.hashInstanceId('salt', 'Living@_airplay._tcp'),
          LanFingerprint.hashInstanceId('salt', 'HP@_printer._tcp'),
        },
      );
      final browser = FakeMdnsBrowser([
        // No homeCastId → Signal A browse is skipped; first call is fingerprint.
        [
          const DiscoveredService(
            instanceName: 'Speaker',
            serviceType: '_googlecast._tcp',
            txt: {'id': 'cast-aaa'},
          ),
          const DiscoveredService(
            instanceName: 'Living',
            serviceType: '_airplay._tcp',
          ),
          const DiscoveredService(
            instanceName: 'HP',
            serviceType: '_printer._tcp',
          ),
        ],
      ]);
      final service = PresenceService(
        browser: browser,
        store: store,
        clock: clock,
      );

      final snap = await service.scan();
      expect(snap.state, PresenceState.home);
      expect(snap.signal, PresenceSignal.b);
    });

    test('browse failure is typed and counts as a false scan (not a crash)',
        () async {
      final browser = FakeMdnsBrowser(const [])
        ..onBrowse = ({required serviceTypes, required budget}) {
          throw PresenceBrowseFailure('radio asleep');
        };
      final service = buildService(browser);

      final snap = await service.scan();
      expect(snap.state, PresenceState.unknown);
      expect(snap.scan.detected, isFalse);
    });
  });

  group('PresenceSchedule §3.6', () {
    test('anchors offsets to the scheduled azan epoch', () {
      final t = DateTime.utc(2026, 8, 10, 19, 2);
      expect(
        PresenceSchedule.at(t, PresenceSchedule.scanOffset),
        DateTime.utc(2026, 8, 10, 19, 0),
      );
      expect(
        PresenceSchedule.at(t, PresenceSchedule.decisionOffset),
        DateTime.utc(2026, 8, 10, 19, 0, 30),
      );
    });

    test('cache older than 10 minutes is stale', () {
      final service = buildService(FakeMdnsBrowser(const []));
      service.applyScanResult(
        PresenceScanResult.detected(signal: PresenceSignal.a),
      );
      expect(service.isCacheStale(clock.now()), isFalse);

      clock.advance(const Duration(minutes: 10, seconds: 1));
      expect(service.isCacheStale(clock.now()), isTrue);
    });
  });
}
