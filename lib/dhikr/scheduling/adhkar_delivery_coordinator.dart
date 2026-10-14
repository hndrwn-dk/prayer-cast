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

/// Plays adhkar audio on the already-connected Cast speaker.
///
/// Cast only (no phone fallback). Callers decide *when* to play (schedule,
/// user-at-home); this class never throws and reports a result instead.
/// Audio is served by the existing [MediaServer] because Cast receivers
/// cannot fetch `data:` URIs.
final class AdhkarDeliveryCoordinator {
  AdhkarDeliveryCoordinator({
    required AdhkarAudioLoader audioLoader,
    required CastClient castClient,
    Future<InternetAddress> Function(InternetAddress receiverHost)?
        resolveHost,
  })  : _audioLoader = audioLoader,
        _castClient = castClient,
        _resolveHost = resolveHost ?? InterfaceSelector().selectFor;

  final AdhkarAudioLoader _audioLoader;
  final CastClient _castClient;
  final Future<InternetAddress> Function(InternetAddress) _resolveHost;

  MediaServer? _server;
  Future<void> _tail = Future<void>.value();

  /// Calls are serialized so a second request never tears down the server
  /// of a play that is still starting.
  Future<AdhkarDeliveryResult> playAdhkar(AdhkarType type) {
    final result = _tail.then((_) => _play(type));
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<AdhkarDeliveryResult> _play(AdhkarType type) async {
    final receiver = _castClient.connected;
    if (receiver == null) return AdhkarDeliveryResult.speakerOffline;

    final audio = await _loadAudio(type);
    if (audio == null || audio.isEmpty) {
      return AdhkarDeliveryResult.audioMissing;
    }

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
      await _castClient.loadAdzan(
        contentId: voiceId,
        contentUrl: server.mediaUri(host),
        title: voiceId,
      );
      return AdhkarDeliveryResult.success;
    } catch (_) {
      await _stopServer();
      return AdhkarDeliveryResult.castFailed;
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
    await server?.stop();
  }
}
