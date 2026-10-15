import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device helpers for counting dhikr without looking at the screen:
/// keep the screen awake, and (Android) count with the volume buttons.
///
/// Every call is best-effort. A platform without the channel (tests, or an
/// OS that cannot intercept volume keys) just reports `false`.
class DhikrDevice {
  DhikrDevice._();

  static final DhikrDevice instance = DhikrDevice._();

  static const MethodChannel _channel = MethodChannel('prayer_cast/dhikr');

  final StreamController<void> _volumeTaps = StreamController<void>.broadcast();
  bool _handlerBound = false;

  /// Fires once per volume-button press while [setVolumeKeyCounting] is on.
  Stream<void> get volumeTaps {
    _bindHandler();
    return _volumeTaps.stream;
  }

  void _bindHandler() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey') _volumeTaps.add(null);
    });
  }

  Future<void> setKeepScreenOn(bool on) =>
      _invoke('setKeepScreenOn', on).then((_) {});

  /// Returns true when the platform will deliver volume presses to
  /// [volumeTaps] instead of changing the media volume.
  Future<bool> setVolumeKeyCounting(bool on) async {
    _bindHandler();
    return await _invoke('setVolumeKeyCounting', on) ?? false;
  }

  Future<bool?> _invoke(String method, bool on) async {
    try {
      return await _channel.invokeMethod<bool>(method, on);
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('DhikrDevice.$method failed: ${e.message}');
      return false;
    }
  }
}
