import 'dart:async';

import '../common/logger.dart';
import '../coordinator/adzan_audio_loader.dart';
import '../delivery/cast_client.dart';
import '../delivery/interface_selector.dart';
import '../delivery/media_server.dart';
import '../presence/fingerprint_store.dart';

enum AdzanCastFailCode {
  busy,
  noSpeaker,
  emptyAudio,
  mediaRejected,
  noFetch,
  generic,
}

/// Manual "play adzan on home speaker" for settings / QA.
final class AdzanCastTester {
  AdzanCastTester({
    required CastClient castClient,
    required FingerprintStore store,
    required AdzanAudioLoader audioLoader,
    InterfaceSelector? interfaces,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _cast = castClient,
        _store = store,
        _audioLoader = audioLoader,
        _interfaces = interfaces ?? InterfaceSelector(logger: logger),
        _logger = logger;

  final CastClient _cast;
  final FingerprintStore _store;
  final AdzanAudioLoader _audioLoader;
  final InterfaceSelector _interfaces;
  final HomeDeliveryLogger _logger;

  MediaServer? _server;
  bool _busy = false;

  bool get isBusy => _busy;

  /// Load [voiceId] and cast to the saved home speaker.
  ///
  /// Success = receiver reaches PLAYING/FINISHED, or at least fetches audio
  /// from the local media server. IDLE alone is not success (often means the
  /// speaker rejected the media URL).
  Future<void> playOnHomeSpeaker({
    required String voiceId,
    required String prayerName,
    Duration statusGrace = const Duration(seconds: 20),
  }) async {
    if (_busy) {
      throw const AdzanCastTestFailure(AdzanCastFailCode.busy);
    }
    _busy = true;
    var loaded = false;
    try {
      final castId = await _store.readHomeCastIdResilient();
      if (castId == null || castId.isEmpty) {
        throw const AdzanCastTestFailure(AdzanCastFailCode.noSpeaker);
      }

      final audio = await _audioLoader.load(voiceId);
      if (audio.bytes.isEmpty) {
        throw const AdzanCastTestFailure(AdzanCastFailCode.emptyAudio);
      }
      if (audio.bytes.length < 2048) {
        _logger.warn(
          'Audio $voiceId is only ${audio.bytes.length} bytes — '
          'likely silent fallback tone',
          tag: 'AdzanCastTester',
        );
      }

      await _stopServer();
      final server = MediaServer(
        audioBytes: audio.bytes,
        voiceId: voiceId,
        contentType: audio.contentType,
        fileExtension: audio.extension,
        logger: _logger,
      );
      await server.start();
      _server = server;

      final receiver = await _cast.connectById(
        castId,
        budget: const Duration(seconds: 12),
      );
      final bindHost = await _interfaces.selectFor(receiver.host);
      final url = server.mediaUri(bindHost);
      final contentId = CastClient.contentIdFor(
        sessionId: 'test-${prayerName}-${DateTime.now().millisecondsSinceEpoch}',
        voiceId: voiceId,
      );

      _logger.info(
        'Test cast URL=$url bytes=${audio.bytes.length} '
        'contentType=${audio.contentType} → ${receiver.friendlyName}',
        tag: 'AdzanCastTester',
      );

      await _cast.applyPlaybackVolume(0.85);

      final playingOrDone = _cast.playbackEvents.firstWhere(
        (e) =>
            e == CastPlaybackEvent.playing ||
            e == CastPlaybackEvent.finished,
      );
      final failed = _cast.playbackEvents.firstWhere(
        (e) => e == CastPlaybackEvent.error,
      );

      await _cast.loadAdzan(
        contentId: contentId,
        contentUrl: url,
        contentType: audio.contentType,
        title: 'Adzan $prayerName',
      );
      loaded = true;

      Object? outcome;
      try {
        outcome = await Future.any<Object>([
          playingOrDone.then((e) => e),
          failed.then((e) => e),
          Future<Object>.delayed(statusGrace, () => 'timeout'),
        ]);
      } catch (e) {
        outcome = e;
      }

      final hits = server.hitCount;
      _logger.info(
        'Test cast outcome=$outcome hits=$hits voice=$voiceId '
        '→ ${receiver.friendlyName}',
        tag: 'AdzanCastTester',
      );

      if (outcome == CastPlaybackEvent.error) {
        throw AdzanCastTestFailure(
          AdzanCastFailCode.mediaRejected,
          hits: hits,
        );
      }

      if (outcome == 'timeout') {
        // Some Xiaomi/Nest firmwares play without PLAYING callbacks. If the
        // speaker fetched bytes, treat as success and keep the session up.
        if (hits == 0) {
          throw const AdzanCastTestFailure(AdzanCastFailCode.noFetch);
        }
        _logger.warn(
          'No PLAYING status within ${statusGrace.inSeconds}s but '
          'speaker fetched audio (hits=$hits); leaving session up',
          tag: 'AdzanCastTester',
        );
      }

      // Keep HTTP server up while the receiver buffers/plays (~4–5 min adhan).
      unawaited(Future<void>.delayed(const Duration(minutes: 6), _stopServer));
    } on AdzanCastTestFailure {
      if (!loaded) {
        await _cleanupCast();
        await _stopServer();
      }
      rethrow;
    } catch (e) {
      if (!loaded) {
        await _cleanupCast();
        await _stopServer();
      }
      throw AdzanCastTestFailure(AdzanCastFailCode.generic, detail: '$e');
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    await _cleanupCast();
    await _stopServer();
  }

  Future<void> _cleanupCast() async {
    try {
      await _cast.endSession();
    } catch (_) {}
  }

  Future<void> _stopServer() async {
    final server = _server;
    _server = null;
    if (server == null) return;
    try {
      await server.stop();
    } catch (_) {}
  }
}

final class AdzanCastTestFailure implements Exception {
  const AdzanCastTestFailure(this.code, {this.hits, this.detail});

  final AdzanCastFailCode code;
  final int? hits;
  final String? detail;

  @override
  String toString() => 'AdzanCastTestFailure($code)';
}
