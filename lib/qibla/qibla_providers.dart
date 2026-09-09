import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compass_heading.dart';
import 'mosque_cache.dart';
import 'mosque_overpass.dart';
import 'mosque_repository.dart';
import 'qibla_haptics.dart';

final compassHeadingSourceProvider = Provider<CompassHeadingSource>((ref) {
  return const DeviceCompassHeadingSource();
});

final compassReadingProvider = StreamProvider.autoDispose<CompassReading>((
  ref,
) {
  return ref.watch(compassHeadingSourceProvider).readings();
});

final qiblaHapticsProvider = Provider<QiblaHaptics>((ref) {
  return const PlatformQiblaHaptics();
});

final mosqueOverpassClientProvider = Provider<MosqueOverpassClient>((ref) {
  return MosqueOverpassClient();
});

/// Injected by the app shell once the documents directory is open. Null here
/// so nothing prefetches over the network in tests or before boot finishes.
final mosqueCacheStoreProvider = Provider<MosqueCacheStore?>((ref) => null);

final mosqueRepositoryProvider = Provider<MosqueRepository>((ref) {
  return MosqueRepository(
    client: ref.watch(mosqueOverpassClientProvider),
    cache: ref.watch(mosqueCacheStoreProvider),
  );
});

typedef MosqueQuery = ({double latitude, double longitude});

final nearbyMosquesProvider = FutureProvider.autoDispose
    .family<MosqueSearchResult, MosqueQuery>((ref, query) {
      return ref
          .watch(mosqueRepositoryProvider)
          .nearby(latitude: query.latitude, longitude: query.longitude);
    });
