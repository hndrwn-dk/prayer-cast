/// Plays beep / phone Adhan on the device (no Cast).
abstract interface class LocalPrayerPlayer {
  /// Short distinctive tone. Completes when playback ends.
  Future<void> playBeep();

  /// Three-note takbir tone. Completes when playback ends.
  Future<void> playTakbir();

  /// Bundled adhan for [voiceId]. When [waitUntilDone] is false, returns after
  /// start so a settings test does not block the UI for the full recording.
  Future<void> playAdhan({
    required String voiceId,
    bool waitUntilDone = true,
  });

  Future<void> stop();
}

/// No-op player for tests / shells that never play locally.
final class SilentLocalPrayerPlayer implements LocalPrayerPlayer {
  const SilentLocalPrayerPlayer();

  @override
  Future<void> playBeep() async {}

  @override
  Future<void> playTakbir() async {}

  @override
  Future<void> playAdhan({
    required String voiceId,
    bool waitUntilDone = true,
  }) async {}

  @override
  Future<void> stop() async {}
}
