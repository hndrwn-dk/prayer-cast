import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../common/logger.dart';
import 'adzan_audio_loader.dart';
import 'local_prayer_player.dart';

/// Android-first local player using the alarm stream so prayer wakes are
/// audible after MainActivity starts. AdzanForegroundService is
/// connectedDevice and does not play audio itself.
final class AudioplayersLocalPrayerPlayer implements LocalPrayerPlayer {
  AudioplayersLocalPrayerPlayer({
    required this._audioLoader,
    this._logger = const SilentLogger(),
    Future<void> Function()? nativeBeep,
  }) : _nativeBeep = nativeBeep;

  static const String beepAssetId = 'beep';
  static const Duration beepTimeout = Duration(seconds: 8);
  static const Duration adhanTimeout = Duration(minutes: 8);

  final AdzanAudioLoader _audioLoader;
  final HomeDeliveryLogger _logger;
  final Future<void> Function()? _nativeBeep;
  AudioPlayer? _player;
  Completer<void>? _playingDone;

  @override
  Future<void> playBeep() async {
    final native = _nativeBeep;
    if (native != null) {
      await native();
      return;
    }
    return _play(
      assetId: beepAssetId,
      waitUntilDone: true,
      timeout: beepTimeout,
      sonification: true,
    );
  }

  @override
  Future<void> playAdhan({
    required String voiceId,
    bool waitUntilDone = true,
  }) {
    return _play(
      assetId: voiceId,
      waitUntilDone: waitUntilDone,
      timeout: adhanTimeout,
      sonification: false,
    );
  }

  @override
  Future<void> stop() async {
    final done = _playingDone;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
    await _release();
  }

  Future<void> _play({
    required String assetId,
    required bool waitUntilDone,
    required Duration timeout,
    required bool sonification,
  }) async {
    await _release();
    final audio = await _audioLoader.load(assetId);
    if (audio.bytes.isEmpty) {
      throw StateError('Local audio $assetId is empty');
    }

    final player = AudioPlayer();
    _player = player;
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1);
    await player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          contentType: sonification
              ? AndroidContentType.sonification
              : AndroidContentType.music,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    _logger.info(
      'Local play $assetId bytes=${audio.bytes.length} '
      'type=${audio.contentType} wait=$waitUntilDone',
      tag: 'LocalPrayerPlayer',
    );

    await player.play(
      BytesSource(audio.bytes, mimeType: audio.contentType),
    );

    if (!waitUntilDone) return;

    final done = Completer<void>();
    StreamSubscription<void>? completeSub;
    completeSub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    _playingDone = done;
    try {
      await done.future.timeout(timeout);
    } on TimeoutException {
      _logger.warn(
        'Local play $assetId timed out after $timeout',
        tag: 'LocalPrayerPlayer',
      );
      await player.stop();
    } finally {
      await completeSub.cancel();
      if (identical(_playingDone, done)) {
        _playingDone = null;
      }
      if (identical(_player, player)) {
        await _release();
      }
    }
  }

  Future<void> _release() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }
}
