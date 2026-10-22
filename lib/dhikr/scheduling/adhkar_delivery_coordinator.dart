import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_audio_loader.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/delivery/interface_selector.dart';
import 'package:prayer_cast/home_delivery/delivery/media_server.dart';

enum AdhkarDeliveryResult {
  success,
  speakerOffline,
  audioMissing,
  castFailed,
}

/// Plays adhkar audio on the saved home Cast speaker.
///
/// Cast only (no phone fallback). A session left open by adzan is reused.
/// Otherwise the saved home Cast id is connected, the same way a manual
/// adzan test does. This class never throws and reports a result instead.
/// Audio is served by the existing [MediaServer] because Cast receivers
/// cannot fetch `data:` URIs. The server stays up after success so a long
/// recitation can finish buffering.
///
/// Receivers stream the 20–30 minute file in ranges rather than buffering
/// it whole, so the phone must stay awake and serving for the entire
/// recitation. [holdUntilFinished] is that wait; the alarm path runs it
/// while the foreground service is still up.
final class AdhkarDeliveryCoordinator {
  AdhkarDeliveryCoordinator({
    required this._audioLoader,
    required this._castClient,
    Future<InternetAddress> Function(InternetAddress receiverHost)?
        resolveHost,
    this._readHomeCastId,
    this._playbackGrace = const Duration(seconds: 20),
    this._minimumHold = const Duration(minutes: 2),
    this._holdMargin = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _resolveHost = resolveHost ?? InterfaceSelector().selectFor,
       _now = now ?? DateTime.now;

  final AdhkarAudioLoader _audioLoader;
  final CastClient _castClient;
  final Future<InternetAddress> Function(InternetAddress) _resolveHost;
  final Future<String?> Function()? _readHomeCastId;
  final Duration _playbackGrace;

  /// Nest / Chromecast can emit `finished` right after load while audio
  /// continues; ignore `finished` until this long after playback started.
  final Duration _minimumHold;

  /// Slack on top of the estimated recitation length before giving up.
  final Duration _holdMargin;
  final DateTime Function() _now;

  /// Bundled adhkar files are 128 kbps CBR MP3.
  static const int assumedBitrateKbps = 128;

  /// Never hold longer than this, whatever the estimate says.
  static const Duration maxHold = Duration(minutes: 38);

  MediaServer? _server;
  DateTime? _startedAt;
  Duration? _lastPlaybackDuration;

  /// Estimated length of the recitation started by the last successful
  /// [playAdhkar], or null when nothing is playing from this phone.
  Duration? get lastPlaybackDuration => _lastPlaybackDuration;

  /// Playback length of a CBR MP3 of [byteLength] bytes at [kbps].
  static Duration estimateDuration(
    int byteLength, {
    int kbps = assumedBitrateKbps,
  }) {
    if (byteLength <= 0 || kbps <= 0) return Duration.zero;
    final ms = byteLength * 8 * 1000 ~/ (kbps * 1000);
    return Duration(milliseconds: ms);
  }
  Future<void> _tail = Future<void>.value();

  /// Calls are serialized so a second request never tears down the server
  /// of a play that is still starting.
  Future<AdhkarDeliveryResult> playAdhkar(AdhkarType type) {
    final result = _tail.then((_) => _play(type));
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<AdhkarDeliveryResult> _play(AdhkarType type) async {
    final reused = _castClient.connected != null;
    final receiver = await _receiver();
    if (receiver == null) return AdhkarDeliveryResult.speakerOffline;

    final audio = await _loadAudio(type);
    if (audio == null || audio.isEmpty) {
      return AdhkarDeliveryResult.audioMissing;
    }

    final first = await _cast(type, receiver, audio);
    if (first != AdhkarDeliveryResult.castFailed || !reused) return first;

    // The kept-open session can die hours before the next adhkar while the
    // process is frozen; the stale receiver then fails every load.
    await _castClient.endSession(restoreVolumeFirst: false);
    final fresh = await _receiver();
    if (fresh == null) return AdhkarDeliveryResult.castFailed;
    return _cast(type, fresh, audio);
  }

  Future<AdhkarDeliveryResult> _cast(
    AdhkarType type,
    CastReceiver receiver,
    Uint8List audio,
  ) async {
    try {
      await _stopServer();
      final voiceId = 'adhkar_${type.name}';
      final server = MediaServer(
        audioBytes: audio,
        voiceId: voiceId,
        fileExtension: 'mp3',
      );
      await server.start();
      _server = server;

      final host = await _resolveHost(receiver.host);
      final playingOrDone = _castClient.playbackEvents.firstWhere(
        (event) =>
            event == CastPlaybackEvent.playing ||
            event == CastPlaybackEvent.finished,
      );
      final failed = _castClient.playbackEvents.firstWhere(
        (event) => event == CastPlaybackEvent.error,
      );
      await _castClient.loadAdzan(
        contentId: voiceId,
        contentUrl: server.mediaUri(host),
        title: voiceId,
      );
      final confirmed = await _confirmPlayback(
        playingOrDone: playingOrDone,
        failed: failed,
        server: server,
      );
      if (!confirmed) {
        await _stopServer();
        return AdhkarDeliveryResult.castFailed;
      }
      _startedAt = _now();
      _lastPlaybackDuration = estimateDuration(audio.length);
      return AdhkarDeliveryResult.success;
    } catch (_) {
      await _stopServer();
      return AdhkarDeliveryResult.castFailed;
    }
  }

  /// Open session, or the saved home speaker. Null means nothing to cast to.
  Future<CastReceiver?> _receiver() async {
    final current = _castClient.connected;
    if (current != null) return current;
    final readHomeCastId = _readHomeCastId;
    if (readHomeCastId == null) return null;
    final castId = await readHomeCastId();
    if (castId == null || castId.isEmpty) return null;
    try {
      return await _castClient.connectById(castId);
    } catch (_) {
      return null;
    }
  }

  /// True once the receiver fetches the file. A loadMedia ack with zero
  /// HTTP hits is the silent-speaker failure, and a PLAYING status alone can
  /// still belong to the media that was on the speaker before this load.
  Future<bool> _confirmPlayback({
    required Future<CastPlaybackEvent> playingOrDone,
    required Future<CastPlaybackEvent> failed,
    required MediaServer server,
  }) async {
    final timedOut = Completer<String>();
    final timer = Timer(_playbackGrace, () {
      if (!timedOut.isCompleted) timedOut.complete('timeout');
    });
    try {
      final outcome = await Future.any<Object>([
        playingOrDone,
        failed,
        timedOut.future,
      ]);
      if (outcome == CastPlaybackEvent.error) return false;
      while (server.hitCount == 0 && !timedOut.isCompleted) {
        final next = await Future.any<Object>([
          failed,
          timedOut.future,
          Future<String>.delayed(const Duration(milliseconds: 200), () => ''),
        ]);
        if (next == CastPlaybackEvent.error) return false;
      }
      return server.hitCount > 0;
    } finally {
      timer.cancel();
    }
  }

  /// Keep serving until the receiver finishes the recitation, then stop the
  /// media server.
  ///
  /// Ends on a Cast `finished` (once [_minimumHold] has passed), on a Cast
  /// `error`, or when the estimated length plus [_holdMargin] runs out.
  /// No-op when nothing was started. Never throws.
  Future<void> holdUntilFinished() async {
    final server = _server;
    final startedAt = _startedAt;
    final estimate = _lastPlaybackDuration;
    if (server == null || startedAt == null || estimate == null) return;
    var limit = estimate + _holdMargin;
    if (limit > maxHold) limit = maxHold;
    final deadline = startedAt.add(limit);
    try {
      while (true) {
        final remaining = deadline.difference(_now());
        if (remaining <= Duration.zero) break;
        final event = await _castClient.playbackEvents
            .firstWhere(
              (e) =>
                  e == CastPlaybackEvent.finished ||
                  e == CastPlaybackEvent.error,
            )
            .timeout(remaining);
        if (event == CastPlaybackEvent.error) break;
        if (_now().difference(startedAt) >= _minimumHold) break;
        // Spurious early finished — audio is likely still playing.
      }
    } catch (_) {
      // Timeout or closed stream: the estimate has run out either way.
    } finally {
      // A newer play may already own a fresh server; leave that one alone.
      if (identical(_server, server)) {
        await _stopServer();
      }
    }
  }

  /// Settings "Test now" entry point.
  Future<AdhkarDeliveryResult> testAdhkar(AdhkarType type) => playAdhkar(type);

  Future<void> dispose() => _stopServer();

  Future<Uint8List?> _loadAudio(AdhkarType type) async {
    try {
      return await _audioLoader.load(type);
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopServer() async {
    final server = _server;
    _server = null;
    _startedAt = null;
    _lastPlaybackDuration = null;
    await server?.stop();
  }
}
