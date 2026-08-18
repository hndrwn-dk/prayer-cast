import 'package:flutter/services.dart';

/// Reads the `prayer` extra from the Android launch / notification Intent.
///
/// MainActivity already forwards FSI extras. This channel does not start
/// delivery — [PrayerDeliveryCoordinator.start] runs before first frame.
final class LaunchPrayer {
  LaunchPrayer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'prayer_cast/launch';

  final MethodChannel _channel;
  void Function(String prayer)? onPrayer;

  void attach() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLaunchPrayer') {
        final prayer = call.arguments as String?;
        if (prayer != null && prayer.isNotEmpty) {
          onPrayer?.call(prayer);
        }
      }
    });
  }

  Future<String?> consume() async {
    try {
      final prayer = await _channel.invokeMethod<String>('consumeLaunchPrayer');
      if (prayer == null || prayer.isEmpty) return null;
      return prayer;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

/// True when [prayer] was already opened within [window] (FSI + tap, or
/// consume + onNewIntent).
bool isDuplicateLaunchPrayer({
  required String prayer,
  String? previousPrayer,
  DateTime? previousAt,
  required DateTime now,
  Duration window = const Duration(seconds: 8),
}) {
  if (previousPrayer != prayer || previousAt == null) return false;
  return now.difference(previousAt) < window;
}
