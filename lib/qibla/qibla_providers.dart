import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compass_heading.dart';
import 'mosque_overpass.dart';

final compassHeadingSourceProvider = Provider<CompassHeadingSource>((ref) {
  return const DeviceCompassHeadingSource();
});

final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  return ref.watch(compassHeadingSourceProvider).headings();
});

final mosqueOverpassClientProvider = Provider<MosqueOverpassClient>((ref) {
  return MosqueOverpassClient();
});

typedef MosqueQuery = ({double latitude, double longitude});

final nearbyMosquesProvider = FutureProvider.autoDispose
    .family<List<NearbyMosque>, MosqueQuery>((ref, query) {
      return ref
          .watch(mosqueOverpassClientProvider)
          .nearby(latitude: query.latitude, longitude: query.longitude);
    });
