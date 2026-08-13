import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';

import 'fake_mdns_browser.dart';

void main() {
  group('LanFingerprint.hashInstanceId §3.3', () {
    test('is deterministic for the same salt and instance id', () {
      final a = LanFingerprint.hashInstanceId('salt', 'cast-abc');
      final b = LanFingerprint.hashInstanceId('salt', 'cast-abc');
      expect(a, b);
      expect(a, hasLength(64));
    });

    test('changes when salt or instance id changes', () {
      final base = LanFingerprint.hashInstanceId('salt', 'cast-abc');
      expect(LanFingerprint.hashInstanceId('other', 'cast-abc'), isNot(base));
      expect(LanFingerprint.hashInstanceId('salt', 'cast-xyz'), isNot(base));
    });
  });

  group('household Cast-id fingerprint / election secret', () {
    test('matches across phones that saved the same speaker', () {
      const nest = '5b3609fd-home-group';
      final a = LanFingerprint.householdFingerprintShort(nest);
      final b = LanFingerprint.householdFingerprintShort(nest);
      expect(a, b);
      expect(a, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(
        LanFingerprint.householdFingerprintShort('other-house'),
        isNot(a),
      );
      expect(
        LanFingerprint.householdElectionSecret(nest),
        LanFingerprint.householdElectionSecret(nest),
      );
      expect(
        LanFingerprint.householdElectionSecret(nest),
        isNot(LanFingerprint.householdElectionSecret('other-house')),
      );
    });

    test('shortHashForHome and electionSecret ignore per-install salt',
        () async {
      const nest = 'cast-shared-nest';
      final phoneA = MemoryFingerprintStore(
        salt: 'salt-phone-a',
        homeCastId: nest,
      );
      final phoneB = MemoryFingerprintStore(
        salt: 'salt-phone-b',
        homeCastId: nest,
      );
      final fpA = LanFingerprint(
        browser: FakeMdnsBrowser(const []),
        store: phoneA,
      );
      final fpB = LanFingerprint(
        browser: FakeMdnsBrowser(const []),
        store: phoneB,
      );
      expect(await fpA.shortHashForHome(), await fpB.shortHashForHome());
      expect(await fpA.electionSecret(), await fpB.electionSecret());
      expect(
        await fpA.electionSecret(),
        LanFingerprint.householdElectionSecret(nest),
      );
    });
  });

  group('LanFingerprint.evaluateSets Jaccard §3.3', () {
    test('matches when J >= 0.4 and overlap >= 2', () {
      final saved = {'a', 'b', 'c', 'd', 'e'};
      final observed = {'a', 'b', 'x'}; // overlap 2, union 6, J=2/6≈0.33 — fail
      expect(LanFingerprint.evaluateSets(saved: saved, observed: observed).matched,
          isFalse);

      final observedOk = {'a', 'b', 'c'}; // overlap 3, union 5, J=0.6
      final result =
          LanFingerprint.evaluateSets(saved: saved, observed: observedOk);
      expect(result.matched, isTrue);
      expect(result.overlap, 3);
      expect(result.jaccard, closeTo(0.6, 1e-9));
    });

    test('rejects high Jaccard with overlap of only 1', () {
      final result = LanFingerprint.evaluateSets(
        saved: {'a'},
        observed: {'a'},
      );
      // J=1.0 but overlap=1 < 2
      expect(result.jaccard, 1.0);
      expect(result.matched, isFalse);
    });
  });

  group('LanFingerprint.captureHome / evaluate', () {
    test('persists salted hashes and evaluates Signal B', () async {
      final store = MemoryFingerprintStore(salt: 'fixed-salt');
      final browser = FakeMdnsBrowser([
        [
          const DiscoveredService(
            instanceName: 'Nest',
            serviceType: '_googlecast._tcp',
            txt: {'id': 'cast-1111'},
          ),
          const DiscoveredService(
            instanceName: 'Living Room',
            serviceType: '_airplay._tcp',
          ),
          const DiscoveredService(
            instanceName: 'HP',
            serviceType: '_printer._tcp',
          ),
        ],
        // Evaluation browse — same three devices.
        [
          const DiscoveredService(
            instanceName: 'Nest',
            serviceType: '_googlecast._tcp',
            txt: {'id': 'cast-1111'},
          ),
          const DiscoveredService(
            instanceName: 'Living Room',
            serviceType: '_airplay._tcp',
          ),
          const DiscoveredService(
            instanceName: 'HP',
            serviceType: '_printer._tcp',
          ),
        ],
      ]);

      final fingerprint = LanFingerprint(browser: browser, store: store);
      final captured = await fingerprint.captureHome();
      expect(captured.hashes, hasLength(3));
      expect(await store.readElectionSecret(), isNotEmpty);
      // Cast id preferred over instanceName@type.
      expect(
        captured.hashes,
        contains(LanFingerprint.hashInstanceId('fixed-salt', 'cast-1111')),
      );
      expect(
        captured.hashes,
        contains(
          LanFingerprint.hashInstanceId(
            'fixed-salt',
            'Living Room@_airplay._tcp',
          ),
        ),
      );

      final evaluation = await fingerprint.evaluate();
      expect(evaluation.matched, isTrue);
      expect(evaluation.overlap, 3);
    });

    test('shortHash is 8 hex chars and stable for the same set', () {
      final hashes = {'aaa', 'bbb'};
      final a = LanFingerprint.shortHash(hashes);
      final b = LanFingerprint.shortHash({'bbb', 'aaa'});
      expect(a, b);
      expect(a, matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });
}
