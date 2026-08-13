import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordination/clock_skew.dart';
import 'package:prayer_cast/home_delivery/coordination/election_message.dart';

void main() {
  group('ClockSkewAnalyzer §4.7', () {
    test('no skew → no demotions', () {
      final decision = ClockSkewAnalyzer.decide(
        selfDeviceId: 'a',
        selfNowEpochMs: 1_000_000,
        peerClaims: [
          const ClaimMessage(
            sessionId: 's',
            deviceId: 'b',
            priority: 40,
            nowEpochMs: 1_001_000,
          ),
        ],
      );
      expect(decision.skewDetected, isFalse);
      expect(decision.demotedDeviceIds, isEmpty);
    });

    test('two devices skewed → higher deviceId demoted', () {
      final decision = ClockSkewAnalyzer.decide(
        selfDeviceId: 'aaa',
        selfNowEpochMs: 1_000_000,
        peerClaims: [
          const ClaimMessage(
            sessionId: 's',
            deviceId: 'zzz',
            priority: 40,
            nowEpochMs: 1_000_000 + 5 * 60 * 1000,
          ),
        ],
      );
      expect(decision.skewDetected, isTrue);
      expect(decision.twoDeviceTieBreak, isTrue);
      expect(decision.demotedDeviceIds, {'zzz'});
    });

    test('three devices: minority clock demoted', () {
      final decision = ClockSkewAnalyzer.decide(
        selfDeviceId: 'a',
        selfNowEpochMs: 1_000_000,
        peerClaims: [
          const ClaimMessage(
            sessionId: 's',
            deviceId: 'b',
            priority: 40,
            nowEpochMs: 1_000_500,
          ),
          const ClaimMessage(
            sessionId: 's',
            deviceId: 'c',
            priority: 40,
            nowEpochMs: 1_000_000 + 5 * 60 * 1000,
          ),
        ],
      );
      expect(decision.skewDetected, isTrue);
      expect(decision.demotedDeviceIds, {'c'});
    });
  });
}
