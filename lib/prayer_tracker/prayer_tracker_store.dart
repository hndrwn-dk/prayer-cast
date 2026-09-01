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

const kQadhaCacheKey = '__qadha__';

/// Outstanding make-up prayers, stored beside the daily log (same file).
class QadhaLedger {
  const QadhaLedger({
    this.counts = const {},
    this.dismissedAccrualDay,
  });

  final Map<String, int> counts;
  final String? dismissedAccrualDay;

  int of(String prayer) {
    final n = counts[prayer] ?? 0;
    return n < 0 ? 0 : n;
  }

  int get total {
    var sum = 0;
    for (final n in counts.values) {
      if (n > 0) sum += n;
    }
    return sum;
  }

  QadhaLedger incremented(String prayer) {
    return QadhaLedger(
      counts: {...counts, prayer: of(prayer) + 1},
      dismissedAccrualDay: dismissedAccrualDay,
    );
  }

  QadhaLedger decremented(String prayer) {
    final next = of(prayer) - 1;
    final map = Map<String, int>.from(counts);
    if (next <= 0) {
      map.remove(prayer);
    } else {
      map[prayer] = next;
    }
    return QadhaLedger(
      counts: map,
      dismissedAccrualDay: dismissedAccrualDay,
    );
  }

  QadhaLedger added(Iterable<String> prayers) {
    var next = this;
    for (final prayer in prayers) {
      next = next.incremented(prayer);
    }
    return next;
  }

  QadhaLedger dismissingAccrual(String dayKey) {
    return QadhaLedger(counts: counts, dismissedAccrualDay: dayKey);
  }

  Map<String, dynamic> toJson() => {
        'counts': {
          for (final e in counts.entries)
            if (e.value > 0) e.key: e.value,
        },
        if (dismissedAccrualDay != null)
          'dismissedAccrualDay': dismissedAccrualDay,
      };

  static QadhaLedger parse(Map<String, dynamic>? raw) {
    if (raw == null) return const QadhaLedger();
    final countsRaw = raw['counts'];
    final counts = <String, int>{};
    if (countsRaw is Map) {
      for (final e in countsRaw.entries) {
        if (e.key is! String) continue;
        final n = e.value;
        final value = n is int ? n : int.tryParse('$n') ?? 0;
        if (value > 0) counts[e.key as String] = value;
      }
    }
    final dismissed = raw['dismissedAccrualDay'];
    return QadhaLedger(
      counts: counts,
      dismissedAccrualDay: dismissed is String ? dismissed : null,
    );
  }
}

abstract interface class PrayerTrackerStore {
  Future<PrayerDayLog> readDay(String dayKey);

  Future<void> writeDay(String dayKey, PrayerDayLog log);

  /// Inclusive `YYYY-MM-DD` range. Missing days are omitted.
  Future<Map<String, PrayerDayLog>> readRange(String fromKey, String toKey);

  Future<QadhaLedger> readQadha();

  Future<void> writeQadha(QadhaLedger ledger);
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
      if (!_isDayKey(entry.key)) continue;
      if (entry.key.compareTo(fromKey) < 0) continue;
      if (entry.key.compareTo(toKey) > 0) continue;
      final decoded = decodeDay(entry.value);
      if (decoded.isNotEmpty) out[entry.key] = decoded;
    }
    return out;
  }

  @override
  Future<QadhaLedger> readQadha() async {
    await _ensureLoaded();
    return QadhaLedger.parse(_cache[kQadhaCacheKey]);
  }

  @override
  Future<void> writeQadha(QadhaLedger ledger) async {
    await _ensureLoaded();
    if (ledger.total == 0 && ledger.dismissedAccrualDay == null) {
      _cache.remove(kQadhaCacheKey);
    } else {
      _cache[kQadhaCacheKey] = ledger.toJson();
    }
    await _persist();
  }

  static bool _isDayKey(String key) =>
      key.length == 10 && key[4] == '-' && key[7] == '-';

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
  QadhaLedger _qadha = const QadhaLedger();

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

  @override
  Future<QadhaLedger> readQadha() async => _qadha;

  @override
  Future<void> writeQadha(QadhaLedger ledger) async {
    _qadha = ledger;
  }
}
