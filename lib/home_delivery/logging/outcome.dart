/// Typed outcome codes written to `delivery_log.outcome` (spec §6.2).
///
/// WHY: Every failure path in this layer must map to one of these codes —
/// silent catches and bare `Exception` rethrows are forbidden. The delivery
/// log UI (§6.3 / Phase 6) renders a plain-language explanation per code.
enum Outcome {
  /// Cast succeeded; receiver reported PLAYING.
  played('PLAYED'),

  /// Presence said AWAY.
  suppressedAway('SUPPRESSED_AWAY'),

  /// Another device led the election.
  suppressedNotLeader('SUPPRESSED_NOT_LEADER'),

  /// Receiver-side duplicate check tripped (§4.8).
  suppressedAlreadyPlaying('SUPPRESSED_ALREADY_PLAYING'),

  /// User quiet hours / guest mode.
  suppressedUserDnd('SUPPRESSED_USER_DND'),

  /// Saved speaker not discoverable.
  failedNoTarget('FAILED_NO_TARGET'),

  /// No interface on the receiver's subnet (§5.2).
  failedNoRoute('FAILED_NO_ROUTE'),

  /// Cast session connect timeout.
  failedCastConnect('FAILED_CAST_CONNECT'),

  /// loadMedia error from the receiver.
  failedLoadMedia('FAILED_LOAD_MEDIA'),

  /// Fired more than 60s late (OEM battery killer).
  failedAlarmMissed('FAILED_ALARM_MISSED'),

  /// Clock skew > 3s detected during election (§4.7).
  clockSkew('CLOCK_SKEW'),

  /// Post-delivery reschedule attempt threw (network fetch failed, permission revoked, etc.).
  failedReschedule('FAILED_RESCHEDULE'),

  /// Reschedule retry armed (15-second wake) after a failed reschedule.
  rescheduleRetryArmed('RESCHEDULE_RETRY_ARMED');

  const Outcome(this.code);

  /// Wire / database value. Stable across releases.
  final String code;

  /// Parse a persisted code. Throws [FormatException] on unknown values so
  /// schema drift surfaces loudly instead of being swallowed.
  static Outcome fromCode(String code) {
    for (final value in Outcome.values) {
      if (value.code == code) return value;
    }
    throw FormatException('Unknown Outcome code: $code');
  }
}

/// Exception that already knows its [Outcome] code (hard requirement #3).
///
/// WHY: Delivery failures carry a typed outcome; coordination can map them
/// without importing the delivery package (spec §7 dependency rule).
abstract interface class OutcomeException implements Exception {
  Outcome get outcome;
}
