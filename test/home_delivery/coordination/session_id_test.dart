import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordination/session_id.dart';

void main() {
  group('SessionId.derive §4.5', () {
    const fingerprint = 'a1b2c3d4';
    // 2026-08-10 12:00:00 UTC
    const epochMs = 1786353600000;

    test('is 16 hex characters', () {
      final id = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      expect(id, hasLength(16));
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('is deterministic across simulated peers with the same inputs', () {
      final peerA = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      final peerB = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      final peerC = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );

      expect(peerA, peerB);
      expect(peerB, peerC);
    });

    test('same minute bucket yields the same id regardless of ms offset', () {
      final atMinute = SessionId.derive(
        prayerName: 'fajr',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      final almostNextMinute = SessionId.derive(
        prayerName: 'fajr',
        scheduledEpochMs: epochMs + 59999,
        homeFingerprintShort: fingerprint,
      );
      expect(atMinute, almostNextMinute);
    });

    test('next minute produces a different sessionId', () {
      final a = SessionId.derive(
        prayerName: 'fajr',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      final b = SessionId.derive(
        prayerName: 'fajr',
        scheduledEpochMs: epochMs + 60000,
        homeFingerprintShort: fingerprint,
      );
      expect(a, isNot(equals(b)));
    });

    test('different prayer names do not collide', () {
      final maghrib = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      final isha = SessionId.derive(
        prayerName: 'isha',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: fingerprint,
      );
      expect(maghrib, isNot(equals(isha)));
    });

    test('two houses with the same SSID name get different sessionIds', () {
      // Spec §8 matrix: "Two houses, same SSID name → Different sessionId".
      // Fingerprint short hash differs per home LAN inventory (§3.3 / §4.5).
      final houseA = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: 'aaaaaaaa',
      );
      final houseB = SessionId.derive(
        prayerName: 'maghrib',
        scheduledEpochMs: epochMs,
        homeFingerprintShort: 'bbbbbbbb',
      );
      expect(houseA, isNot(equals(houseB)));
    });

    test('rejects fingerprint short hashes that are not 8 chars', () {
      expect(
        () => SessionId.derive(
          prayerName: 'maghrib',
          scheduledEpochMs: epochMs,
          homeFingerprintShort: 'abcd',
        ),
        throwsArgumentError,
      );
    });
  });
}
