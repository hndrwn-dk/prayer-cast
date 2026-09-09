import 'package:flutter/foundation.dart';

import 'next_prayer_provider.dart';

/// In-memory UI signal: prayer this device is currently delivering.
///
/// Does not arm alarms. Cleared on process death (acceptable).
final class ActiveDeliveryHero {
  final ValueNotifier<NextPrayer?> _current = ValueNotifier<NextPrayer?>(null);

  NextPrayer? get current => _current.value;

  Listenable get listenable => _current;

  void begin(NextPrayer prayer) {
    _current.value = prayer;
  }

  void clear() {
    _current.value = null;
  }

  void dispose() {
    _current.dispose();
  }
}
