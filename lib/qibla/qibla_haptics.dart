import 'package:flutter/services.dart';

/// One short tap when the needle first locks on to the qibla.
abstract interface class QiblaHaptics {
  Future<void> alignedTap();
}

/// Platform haptic tap.
///
/// Flutter exposes no API for the OS "system haptics / vibrate on touch"
/// switch, so there is nothing to read before buzzing. [HapticFeedback]
/// routes through the platform haptic service on both Android and iOS, which
/// stays silent on most devices when the user turned system haptics off, so
/// [HapticFeedback.lightImpact] is the closest thing to respecting it.
final class PlatformQiblaHaptics implements QiblaHaptics {
  const PlatformQiblaHaptics();

  @override
  Future<void> alignedTap() => HapticFeedback.lightImpact();
}

/// Counts taps in tests instead of poking the platform channel.
final class RecordingQiblaHaptics implements QiblaHaptics {
  int taps = 0;

  @override
  Future<void> alignedTap() async => taps++;
}
