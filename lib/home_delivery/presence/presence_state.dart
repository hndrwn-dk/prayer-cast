/// Presence state machine states (spec §3.4).
///
/// WHY: Cast devices drop off mDNS transiently; the machine starts at
/// [unknown] and only moves to [away] after two consecutive false scans
/// spanning >= 90s. A single failed scan must never flip to away.
enum PresenceState {
  unknown,
  home,
  away,
}

/// Which presence signal fired (§3.2). `none` when away / undecided.
enum PresenceSignal {
  /// Saved home Cast target discoverable via mDNS.
  a,

  /// LAN fingerprint Jaccard match.
  b,

  /// Wi-Fi BSSID — opt-in only (§3.5).
  c,

  /// Geofence — opt-in only.
  d,

  none,
}
