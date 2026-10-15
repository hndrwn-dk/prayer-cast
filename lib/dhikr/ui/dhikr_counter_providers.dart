import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';

/// Provider for DhikrCounterStore (overridden in main.dart with File store).
final dhikrCounterStoreProvider = Provider<DhikrCounterStore>((ref) {
  throw UnimplementedError('DhikrCounterStore must be overridden');
});

/// Provider for a specific dhikr counter state.
final dhikrCounterProvider = FutureProvider.family<DhikrCounterState?, String>(
  (ref, dhikrId) async {
    final store = ref.watch(dhikrCounterStoreProvider);
    return store.get(dhikrId);
  },
);

Future<void> incrementDhikrCounter(
  WidgetRef ref,
  String dhikrId,
  int target,
) async {
  final store = ref.read(dhikrCounterStoreProvider);
  await store.increment(dhikrId, target: target);
  ref.invalidate(dhikrCounterProvider(dhikrId));
}

Future<void> resetDhikrCounter(WidgetRef ref, String dhikrId) async {
  final store = ref.read(dhikrCounterStoreProvider);
  await store.reset(dhikrId);
  ref.invalidate(dhikrCounterProvider(dhikrId));
}

Future<void> decrementDhikrCounter(WidgetRef ref, String dhikrId) async {
  final store = ref.read(dhikrCounterStoreProvider);
  await store.decrement(dhikrId);
  ref.invalidate(dhikrCounterProvider(dhikrId));
}
