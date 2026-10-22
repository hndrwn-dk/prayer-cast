import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

/// Decides whether the home speaker is really busy before adhkar starts.
///
/// The Cast SDK's `mediaStatus` is the last status this process received.
/// After an adhan the foreground service stops and the process is frozen,
/// so that cached status can still say PLAYING (our adhan) when the adhkar
/// alarm fires 5–10 minutes later. Treating it as busy made adhkar wait,
/// retry once against the same stale status, and log `cast busy` without
/// ever playing.
abstract final class AdhkarCastBusy {
  /// Our adhan cannot still be playing after this: the orchestrator stops
  /// its media server 6 minutes after azan.
  static const Duration ownAdhanMaxLive = Duration(minutes: 6);

  /// Our adhkar cannot still be playing after the longest hold.
  static const Duration ownAdhkarMaxLive = Duration(minutes: 40);

  /// Title prefix the adhan orchestrator loads with (`adzan:$session:$voice`).
  static const String adhanTitlePrefix = 'adzan:';

  /// Title prefix adhkar loads with (`adhkar_morning`, `adhkar_evening`).
  static const String adhkarTitlePrefix = 'adhkar_';

  static bool isBusy({
    required CastMediaSnapshot? media,
    required DateTime? lastOwnLoadAt,
    required DateTime now,
  }) {
    if (media == null || !media.isPlaying) return false;
    final title = media.title ?? '';
    final Duration maxLive;
    if (title.startsWith(adhanTitlePrefix)) {
      maxLive = ownAdhanMaxLive;
    } else if (title.startsWith(adhkarTitlePrefix)) {
      maxLive = ownAdhkarMaxLive;
    } else {
      // Someone else's media (music, another app): respect it.
      return true;
    }
    // Our own media but no load recorded in this process: the status came
    // from a fresh session, so it is live. Stay conservative.
    if (lastOwnLoadAt == null) return true;
    return now.difference(lastOwnLoadAt) < maxLive;
  }
}
