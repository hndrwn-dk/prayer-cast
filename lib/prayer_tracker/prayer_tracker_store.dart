import 'dart:convert';
import 'dart:io';

/// When the prayer was performed.
enum PrayerLogTiming {
  onTime,
  late,
}

/// Where the prayer was performed.
enum PrayerLogWhere {
  alone,
  jamaah,
}

extension PrayerLogTimingX on PrayerLogTiming {
  String get wire => name;

  static PrayerLogTiming? parse(String? raw) {
    return switch (raw) {
      'onTime' => PrayerLogTiming.onTime,
      'late' => PrayerLogTiming.late,
      _ => null,
    };
  }
}

extension PrayerLogWhereX on PrayerLogWhere {
  String get wire => name;

  static PrayerLogWhere? parse(String? raw) {
    return switch (raw) {
      'alone' => PrayerLogWhere.alone,
      'jamaah' => PrayerLogWhere.jamaah,
      _ => null,
    };
  }
}

/// One prayer log — timing and where are independent (e.g. on time + alone).
class PrayerLogEntry {
  const PrayerLogEntry({this.timing, this.where});

  final PrayerLogTiming? timing;
  final PrayerLogWhere? where;

  bool get isEmpty => timing == null && where == null;

  bool get isLogged => !isEmpty;

  Map<String, String> toJson() => {
        if (timing != null) 'timing': timing!.wire,
        if (where != null) 'where': where!.wire,
      };

  static PrayerLogEntry? parse(dynamic raw) {
    if (raw is String) return _fromLegacyWire(raw);
    if (raw is Map) {
      final timing = PrayerLogTimingX.parse(raw['timing'] as String?);
      final where = PrayerLogWhereX.parse(raw['where'] as String?);
      if (timing == null && where == null) return null;
      return PrayerLogEntry(timing: timing, where: where);
    }
    return null;
  }

  static PrayerLogEntry? _fromLegacyWire(String raw) {
    return switch (raw) {
      'onTime' => const PrayerLogEntry(timing: PrayerLogTiming.onTime),
      'late' => const PrayerLogEntry(timing: PrayerLogTiming.late),
      'jamaah' => const PrayerLogEntry(where: PrayerLogWhere.jamaah),
      'alone' => const PrayerLogEntry(where: PrayerLogWhere.alone),
      _ => null,
    };
  }
}

/// One day's prayer log (`YYYY-MM-DD` → prayer → entry).
typedef PrayerDayLog = Map<String, PrayerLogEntry>;

abstract interface class PrayerTrackerStore {
  Future<PrayerDayLog> readDay(String dayKey);

  Future<void> writeDay(String dayKey, PrayerDayLog log);

  /// Inclusive `YYYY-MM-DD` range. Missing days are omitted.
  Future<Map<String, PrayerDayLog>> readRange(String fromKey, String toKey);
}

final class FilePrayerTrackerStore implements PrayerTrackerStore {
  FilePrayerTrackerStore(this._file);

  final File _file;
  Map<String, Map<String, dynamic>> _cache = {};
  bool _loaded = false;

  static String dayKey(DateTime day) {
    final local = day.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (!await _file.exists()) return;
    try {
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _cache = {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: {
              for (final inner in (entry.value as Map).entries)
                if (inner.key is String) inner.key as String: inner.value,
            },
      };
    } catch (_) {}
  }

  Future<void> _persist() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_cache));
  }

  static PrayerDayLog decodeDay(Map<String, dynamic> raw) {
    final out = <String, PrayerLogEntry>{};
    for (final entry in raw.entries) {
      final parsed = PrayerLogEntry.parse(entry.value);
      if (parsed != null && parsed.isLogged) out[entry.key] = parsed;
    }
    return out;
  }

  @override
  Future<PrayerDayLog> readDay(String dayKey) async {
    await _ensureLoaded();
    final raw = _cache[dayKey];
    if (raw == null) return {};
    return decodeDay(raw);
  }

  @override
  Future<Map<String, PrayerDayLog>> readRange(
    String fromKey,
    String toKey,
  ) async {
    await _ensureLoaded();
    final out = <String, PrayerDayLog>{};
    for (final entry in _cache.entries) {
      if (entry.key.compareTo(fromKey) < 0) continue;
      if (entry.key.compareTo(toKey) > 0) continue;
      final decoded = decodeDay(entry.value);
      if (decoded.isNotEmpty) out[entry.key] = decoded;
    }
    return out;
  }

  @override
  Future<void> writeDay(String dayKey, PrayerDayLog log) async {
    await _ensureLoaded();
    if (log.isEmpty) {
      _cache.remove(dayKey);
    } else {
      _cache[dayKey] = {
        for (final e in log.entries)
          if (e.value.isLogged) e.key: e.value.toJson(),
      };
    }
    await _persist();
  }
}

final class MemoryPrayerTrackerStore implements PrayerTrackerStore {
  final Map<String, PrayerDayLog> _days = {};

  @override
  Future<PrayerDayLog> readDay(String dayKey) async {
    return Map<String, PrayerLogEntry>.from(_days[dayKey] ?? {});
  }

  @override
  Future<void> writeDay(String dayKey, PrayerDayLog log) async {
    if (log.isEmpty) {
      _days.remove(dayKey);
    } else {
      _days[dayKey] = Map<String, PrayerLogEntry>.from(log);
    }
  }

  @override
  Future<Map<String, PrayerDayLog>> readRange(
    String fromKey,
    String toKey,
  ) async {
    final out = <String, PrayerDayLog>{};
    for (final entry in _days.entries) {
      if (entry.key.compareTo(fromKey) < 0) continue;
      if (entry.key.compareTo(toKey) > 0) continue;
      if (entry.value.isEmpty) continue;
      out[entry.key] = Map<String, PrayerLogEntry>.from(entry.value);
    }
    return out;
  }
}
