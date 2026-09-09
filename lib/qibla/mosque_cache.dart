import 'dart:convert';
import 'dart:io';

import 'mosque_overpass.dart';

/// Mosques do not move. Holding an answer for a month keeps a volunteer-run
/// Overpass out of the loop on every visit.
const Duration kMosqueCacheTtl = Duration(days: 30);

/// Cache cell size — roughly 1.1 km, so walking around a neighbourhood reuses
/// one answer instead of firing a query per street corner.
const double kMosqueCacheCellDegrees = 0.01;

/// Cells kept on disk before the oldest are dropped.
const int kMosqueCacheMaxCells = 24;

/// Coordinates rounded to a [kMosqueCacheCellDegrees] grid.
String mosqueCacheKey({required double latitude, required double longitude}) {
  return '${_snap(latitude)},${_snap(longitude)}';
}

String _snap(double value) {
  final snapped =
      (value / kMosqueCacheCellDegrees).roundToDouble() *
      kMosqueCacheCellDegrees;
  // Keeps a hair below zero from writing "-0.00".
  return (snapped == 0 ? 0.0 : snapped).toStringAsFixed(2);
}

/// One cached Overpass answer for a cell.
final class MosqueCacheEntry {
  const MosqueCacheEntry({
    required this.mosques,
    required this.radiusMeters,
    required this.fetchedAt,
  });

  final List<NearbyMosque> mosques;

  /// Ladder tier the answer came from.
  final int radiusMeters;

  final DateTime fetchedAt;

  bool isFreshAt(DateTime now) => now.difference(fetchedAt) < kMosqueCacheTtl;

  Map<String, Object?> toJson() {
    return {
      'radius': radiusMeters,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'mosques': [
        for (final mosque in mosques)
          {
            'id': mosque.id,
            'name': mosque.name,
            'kind': mosque.kind.name,
            'lat': mosque.latitude,
            'lon': mosque.longitude,
          },
      ],
    };
  }

  /// Null for anything unreadable; a corrupt cell just re-queries.
  static MosqueCacheEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fetchedAt = DateTime.tryParse(raw['fetchedAt']?.toString() ?? '');
    if (fetchedAt == null) return null;
    final radius = (raw['radius'] as num?)?.toInt();
    if (radius == null) return null;
    final rawMosques = raw['mosques'];
    if (rawMosques is! List) return null;
    final mosques = <NearbyMosque>[];
    for (final item in rawMosques) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      final lat = (item['lat'] as num?)?.toDouble();
      final lon = (item['lon'] as num?)?.toDouble();
      if (id.isEmpty || lat == null || lon == null) continue;
      mosques.add(
        NearbyMosque(
          id: id,
          name: item['name']?.toString() ?? '',
          kind: item['kind']?.toString() == NearbyMosqueKind.mosque.name
              ? NearbyMosqueKind.mosque
              : NearbyMosqueKind.prayerRoom,
          latitude: lat,
          longitude: lon,
          // Recomputed against the live origin on read.
          distanceMeters: 0,
          bearingDegrees: 0,
        ),
      );
    }
    return MosqueCacheEntry(
      mosques: mosques,
      radiusMeters: radius,
      fetchedAt: fetchedAt,
    );
  }
}

abstract interface class MosqueCacheStore {
  Future<MosqueCacheEntry?> read(String key);

  Future<void> write(String key, MosqueCacheEntry entry);
}

/// In-memory store for tests and for runs where no documents directory is
/// available.
final class MemoryMosqueCacheStore implements MosqueCacheStore {
  final Map<String, MosqueCacheEntry> _cells = {};

  @override
  Future<MosqueCacheEntry?> read(String key) async => _cells[key];

  @override
  Future<void> write(String key, MosqueCacheEntry entry) async {
    _cells[key] = entry;
  }
}

/// JSON-file cache, one object keyed by cell. Read once, then served from
/// memory; every failure degrades to "no cache" rather than an error.
final class FileMosqueCacheStore implements MosqueCacheStore {
  FileMosqueCacheStore(this._file, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final File _file;
  final DateTime Function() _clock;

  Map<String, MosqueCacheEntry>? _cells;

  @override
  Future<MosqueCacheEntry?> read(String key) async {
    final cells = await _load();
    return cells[key];
  }

  @override
  Future<void> write(String key, MosqueCacheEntry entry) async {
    final cells = await _load();
    cells[key] = entry;
    _prune(cells);
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        jsonEncode({
          for (final cell in cells.entries) cell.key: cell.value.toJson(),
        }),
      );
    } catch (_) {
      // Disk full or read-only: the in-memory copy still serves this run.
    }
  }

  Future<Map<String, MosqueCacheEntry>> _load() async {
    final loaded = _cells;
    if (loaded != null) return loaded;
    final cells = <String, MosqueCacheEntry>{};
    try {
      if (await _file.exists()) {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is Map) {
          for (final cell in decoded.entries) {
            final entry = MosqueCacheEntry.fromJson(cell.value);
            if (entry == null) continue;
            if (!entry.isFreshAt(_clock())) continue;
            cells[cell.key.toString()] = entry;
          }
        }
      }
    } catch (_) {
      cells.clear();
    }
    _cells = cells;
    return cells;
  }

  void _prune(Map<String, MosqueCacheEntry> cells) {
    final now = _clock();
    cells.removeWhere((_, entry) => !entry.isFreshAt(now));
    if (cells.length <= kMosqueCacheMaxCells) return;
    final oldestFirst = cells.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    for (final stale in oldestFirst.take(cells.length - kMosqueCacheMaxCells)) {
      cells.remove(stale.key);
    }
  }
}
