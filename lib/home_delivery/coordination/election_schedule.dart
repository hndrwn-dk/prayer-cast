/// Election timeline offsets relative to scheduled azan T (spec §4.6, §4.9).
///
/// WHY: Hard requirement #4 — every wait is anchored to the scheduled epoch,
/// never to accumulated Timer drift.
final class ElectionSchedule {
  const ElectionSchedule._();

  /// T−30 s — claim window opens; CLAIM every 2 s.
  static const Duration claimStart = Duration(seconds: -30);

  /// T−22 s — claim window closes; rank and decide (or solo fast path).
  static const Duration claimEnd = Duration(seconds: -22);

  /// T−20 s — LEAD window ends; leader begins prepare.
  static const Duration leadEnd = Duration(seconds: -20);

  /// T−5 s — leader starts HTTP server / pre-connects Cast (§3.6 / §5.1).
  static const Duration prepare = Duration(seconds: -5);

  /// T+0 — loadMedia + PLAYING.
  static const Duration azan = Duration.zero;

  /// Staggered failover promotions for rank-2 / rank-3 / rank-4.
  static const List<Duration> failoverOffsets = [
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  /// Hard stop for followers with no failover slot (rank-5+) or that never
  /// heard PLAYING. Past this, election must return — not spin forever.
  static const Duration followerGiveUp = Duration(seconds: 30);

  /// Spacing between consecutive failover ranks (T+4 → T+8 → T+12).
  static Duration get failoverStagger =>
      failoverOffsets[1] - failoverOffsets[0];

  /// Gap between the two LEAD broadcasts from a promoted leader (UDP loss).
  static const Duration promotedLeadRepeat = Duration(seconds: 1);

  static const Duration claimInterval = Duration(seconds: 2);

  /// Clock skew threshold (§4.7).
  static const int skewThresholdMs = 3000;

  static DateTime at(DateTime scheduledAzan, Duration offset) =>
      scheduledAzan.add(offset);
}
