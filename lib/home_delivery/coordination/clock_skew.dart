import 'election_schedule.dart';
import 'election_message.dart';

/// Clock skew analysis for one election session (spec §4.7).
///
/// WHY: A phone whose clock is minutes fast would otherwise win every
/// election and fire early. CLAIM.now lets peers detect skew > 3s; every
/// peer demotes the minority clock(s) to priority 0 when ranking so the
/// decision stays consistent. With only two devices there is no majority —
/// the lower deviceId leads.
final class ClockSkewAnalyzer {
  const ClockSkewAnalyzer._();

  /// Result of comparing [selfNowEpochMs] against peer CLAIM timestamps.
  static ClockSkewDecision decide({
    required String selfDeviceId,
    required int selfNowEpochMs,
    required List<ClaimMessage> peerClaims,
  }) {
    if (peerClaims.isEmpty) {
      return const ClockSkewDecision(
        skewDetected: false,
        demotedDeviceIds: {},
        twoDeviceTieBreak: false,
      );
    }

    var anySkew = false;
    for (final claim in peerClaims) {
      final skew = (selfNowEpochMs - claim.nowEpochMs).abs();
      if (skew > ElectionSchedule.skewThresholdMs) {
        anySkew = true;
        break;
      }
    }
    if (!anySkew) {
      return const ClockSkewDecision(
        skewDetected: false,
        demotedDeviceIds: {},
        twoDeviceTieBreak: false,
      );
    }

    // Exactly one peer (two devices total) — lower deviceId leads (§4.7).
    if (peerClaims.length == 1) {
      final other = peerClaims.single;
      final lower = selfDeviceId.compareTo(other.deviceId) < 0
          ? selfDeviceId
          : other.deviceId;
      final higher = lower == selfDeviceId ? other.deviceId : selfDeviceId;
      return ClockSkewDecision(
        skewDetected: true,
        demotedDeviceIds: {higher},
        twoDeviceTieBreak: true,
      );
    }

    // 3+ devices: largest cluster within 3s is the majority; everyone else
    // is demoted so all peers compute the same ranking.
    final samples = <_ClockSample>[
      _ClockSample(selfDeviceId, selfNowEpochMs),
      for (final c in peerClaims) _ClockSample(c.deviceId, c.nowEpochMs),
    ];
    final majorityIds =
        _largestCluster(samples).map((s) => s.deviceId).toSet();
    final demoted = samples
        .map((s) => s.deviceId)
        .where((id) => !majorityIds.contains(id))
        .toSet();
    return ClockSkewDecision(
      skewDetected: true,
      demotedDeviceIds: demoted,
      twoDeviceTieBreak: false,
    );
  }

  static List<_ClockSample> _largestCluster(List<_ClockSample> samples) {
    var best = <_ClockSample>[];
    for (final anchor in samples) {
      final cluster = samples
          .where(
            (s) =>
                (s.nowEpochMs - anchor.nowEpochMs).abs() <=
                ElectionSchedule.skewThresholdMs,
          )
          .toList();
      if (cluster.length > best.length) {
        best = cluster;
      }
    }
    return best;
  }
}

final class ClockSkewDecision {
  const ClockSkewDecision({
    required this.skewDetected,
    required this.demotedDeviceIds,
    required this.twoDeviceTieBreak,
  });

  final bool skewDetected;

  /// Device ids that must be treated as priority 0 when ranking.
  final Set<String> demotedDeviceIds;

  /// Two-device special case: lower deviceId leads (§4.7).
  final bool twoDeviceTieBreak;
}

final class _ClockSample {
  const _ClockSample(this.deviceId, this.nowEpochMs);

  final String deviceId;
  final int nowEpochMs;
}
