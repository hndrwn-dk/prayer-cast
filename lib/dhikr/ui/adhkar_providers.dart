import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';

/// Overridden in main.dart with the file-backed store.
final adhkarPrefsProvider = Provider<AdhkarPrefs>((ref) {
  throw UnimplementedError('AdhkarPrefs must be overridden');
});

/// Null when no Cast delivery is wired; "Test now" is then disabled.
final adhkarDeliveryCoordinatorProvider =
    Provider<AdhkarDeliveryCoordinator?>((ref) => null);

final adhkarEnabledProvider = StateProvider.family<bool, AdhkarType>(
  (ref, type) => ref.watch(adhkarPrefsProvider).enabled(type),
);

final adhkarDelayProvider = StateProvider.family<int, AdhkarType>(
  (ref, type) => ref.watch(adhkarPrefsProvider).delayMinutes(type),
);

Future<void> toggleAdhkarEnabled(
  WidgetRef ref,
  AdhkarType type,
  bool enabled,
) async {
  final prefs = ref.read(adhkarPrefsProvider);
  await prefs.setEnabled(type, enabled);
  await prefs.save();
  ref.read(adhkarEnabledProvider(type).notifier).state = enabled;
}

Future<void> updateAdhkarDelay(
  WidgetRef ref,
  AdhkarType type,
  int minutes,
) async {
  final prefs = ref.read(adhkarPrefsProvider);
  await prefs.setDelayMinutes(type, minutes);
  await prefs.save();
  ref.read(adhkarDelayProvider(type).notifier).state = minutes;
}
