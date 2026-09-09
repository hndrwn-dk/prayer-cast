import 'mosque_cache.dart';
import 'mosque_overpass.dart';

/// A list of mosques plus where it came from, so the UI can say when it is
/// showing something it could not refresh.
final class MosqueSearchResult {
  const MosqueSearchResult({
    required this.mosques,
    required this.radiusMeters,
    required this.fetchedAt,
    required this.stale,
  });

  final List<NearbyMosque> mosques;

  /// Radius that produced these rows; the map uses a quarter of it to decide
  /// when panning has gone far enough to offer "Search here".
  final int radiusMeters;

  final DateTime fetchedAt;

  /// True when the network failed and these rows came off disk.
  final bool stale;
}

/// Cache-first access to nearby mosques.
///
/// The cache is the primary source: a warm cell is served without touching
/// the network at all, which is what makes the Qibla-screen prefetch free on
/// a repeat visit.
final class MosqueRepository {
  MosqueRepository({
    required this.client,
    this.cache,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MosqueOverpassClient client;

  /// Null when the app shell has no place to persist to. Everything still
  /// works; nothing is remembered between runs.
  final MosqueCacheStore? cache;

  final DateTime Function() _clock;

  Future<MosqueSearchResult> nearby({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final key = mosqueCacheKey(latitude: latitude, longitude: longitude);
    final cached = await _read(key);
    if (!forceRefresh && cached != null && cached.isFreshAt(_clock())) {
      return _fromCache(cached, latitude, longitude, stale: false);
    }
    try {
      final page = await client.nearby(
        latitude: latitude,
        longitude: longitude,
      );
      final fetchedAt = _clock();
      await _write(
        key,
        MosqueCacheEntry(
          mosques: page.mosques,
          radiusMeters: page.radiusMeters,
          fetchedAt: fetchedAt,
        ),
      );
      return MosqueSearchResult(
        mosques: page.mosques,
        radiusMeters: page.radiusMeters,
        fetchedAt: fetchedAt,
        stale: false,
      );
    } catch (_) {
      if (cached != null) {
        return _fromCache(cached, latitude, longitude, stale: true);
      }
      rethrow;
    }
  }

  /// Warms the cell behind [latitude]/[longitude] so the mosque map opens
  /// with rows already in hand.
  ///
  /// Never touches the network when the cell is warm, and never surfaces an
  /// error: this runs behind a screen that is about the compass, not mosques.
  Future<void> prefetch({
    required double latitude,
    required double longitude,
  }) async {
    if (cache == null) return;
    final key = mosqueCacheKey(latitude: latitude, longitude: longitude);
    final cached = await _read(key);
    if (cached != null && cached.isFreshAt(_clock())) return;
    try {
      await nearby(latitude: latitude, longitude: longitude);
    } catch (_) {
      // The map screen will retry and can explain itself; this cannot.
    }
  }

  /// Cached rows were measured from the cell they were fetched in, which is
  /// up to ~1 km away from where they are being read.
  MosqueSearchResult _fromCache(
    MosqueCacheEntry entry,
    double latitude,
    double longitude, {
    required bool stale,
  }) {
    final rebased = [
      for (final mosque in entry.mosques)
        mosque.relativeTo(latitude: latitude, longitude: longitude),
    ]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return MosqueSearchResult(
      mosques: rebased,
      radiusMeters: entry.radiusMeters,
      fetchedAt: entry.fetchedAt,
      stale: stale,
    );
  }

  Future<MosqueCacheEntry?> _read(String key) async {
    try {
      return await cache?.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, MosqueCacheEntry entry) async {
    try {
      await cache?.write(key, entry);
    } catch (_) {
      // A cache that cannot be written is still a working search.
    }
  }
}
