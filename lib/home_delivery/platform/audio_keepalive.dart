import 'package:flutter/services.dart';

import '../common/logger.dart';

/// Port for iOS silent audio keepalive (injectable for unit tests).
abstract interface class AudioKeepalivePlatform {
  Future<void> start();

  Future<void> stop();

  Future<bool> isActive();
}

/// iOS `AVAudioSession` silent keepalive (spec §5.5).
///
/// WHY: iOS has no exact background execution. Best effort is an active audio
/// session with a silent keepalive track while the app was opened recently
/// and the device is charging. Be honest in the UI about unreliability —
/// for reliable unattended adzan, run the hub build on an always-on device.
final class AudioKeepalive implements AudioKeepalivePlatform {
  AudioKeepalive({
    MethodChannel? methodChannel,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _methods = methodChannel ??
            const MethodChannel('prayer_cast/audio_keepalive'),
        _logger = logger;

  final MethodChannel _methods;
  final HomeDeliveryLogger _logger;

  @override
  Future<void> start() async {
    try {
      await _methods.invokeMethod<void>('start');
    } on PlatformException catch (e, st) {
      _logger.error(
        'AudioKeepalive.start failed',
        tag: 'AudioKeepalive',
        error: e,
        stackTrace: st,
      );
      throw AudioKeepaliveFailure('start failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } on PlatformException catch (e, st) {
      _logger.warn(
        'AudioKeepalive.stop failed',
        tag: 'AudioKeepalive',
        error: e,
        stackTrace: st,
      );
      throw AudioKeepaliveFailure('stop failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<bool> isActive() async {
    try {
      final value = await _methods.invokeMethod<bool>('isActive');
      return value ?? false;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'AudioKeepalive.isActive failed',
        tag: 'AudioKeepalive',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}

/// Typed keepalive failure.
final class AudioKeepaliveFailure implements Exception {
  AudioKeepaliveFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AudioKeepaliveFailure: $message';
}
