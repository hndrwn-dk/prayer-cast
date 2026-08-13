/// Azan-relative presence / coordination timeline offsets (spec §3.6).
///
/// WHY: All timing is anchored to the scheduled azan epoch (hard requirement
/// #4), never to accumulated `DateTime.now()` deltas across awaits. Callers
/// pass the scheduled instant and derive absolute deadlines from these
/// constants.
final class PresenceSchedule {
  const PresenceSchedule._();

  /// T−120 s — wake, Wi-Fi lock, run presence scan (budget 8 s).
  static const Duration scanOffset = Duration(seconds: -120);

  /// T−90 s — presence decided; if AWAY, cancel session.
  static const Duration decisionOffset = Duration(seconds: -90);

  /// T−30 s — open coordination window (§4).
  static const Duration coordinationOffset = Duration(seconds: -30);

  /// T−20 s — leader starts HTTP server / pre-connects Cast.
  static const Duration prepareOffset = Duration(seconds: -20);

  /// Cached presence results older than this are stale (§3.6).
  static const Duration cacheTtl = Duration(minutes: 10);

  /// Absolute instant for an offset relative to scheduled azan time [t].
  static DateTime at(DateTime scheduledAzan, Duration offset) =>
      scheduledAzan.add(offset);

  /// Whether [now] is at or past the presence decision deadline (T−90).
  static bool isPastDecision(DateTime scheduledAzan, DateTime now) =>
      !now.isBefore(at(scheduledAzan, decisionOffset));

  /// Whether a cached result taken at [resultAt] is still fresh at [now].
  static bool isCacheFresh(DateTime resultAt, DateTime now) =>
      now.difference(resultAt) <= cacheTtl;
}
