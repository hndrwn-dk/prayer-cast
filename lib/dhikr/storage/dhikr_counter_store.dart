import 'dart:convert';
import 'dart:io';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';

/// Storage for dhikr counter states.
abstract class DhikrCounterStore {
  Future<DhikrCounterState?> get(String dhikrId);
  Future<void> increment(String dhikrId, {required int target});
  Future<void> decrement(String dhikrId);
  Future<void> reset(String dhikrId);
  Future<void> setTarget(String dhikrId, int target);
}

/// File-based counter store using JSON (pattern matches prayer_tracker.json).
final class FileDhikrCounterStore implements DhikrCounterStore {
  FileDhikrCounterStore(this._file);

  final File _file;
  final Map<String, DhikrCounterState> _cache = {};

  /// Memoized so concurrent first calls share one read instead of each
  /// re-reading the file over counts already changed in memory.
  Future<void>? _loading;

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    if (!await _file.exists()) return;

    try {
      final content = await _file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final parsed = <String, DhikrCounterState>{
        for (final entry in json.entries)
          entry.key: DhikrCounterState.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
      _cache.addAll(parsed);
    } catch (_) {
      // Corrupted or unreadable file: start fresh.
    }
  }

  /// Writes are chained so rapid taps never run two writes to the same
  /// file at once; each write snapshots the cache when it starts.
  Future<void> _writes = Future<void>.value();

  Future<void> _save() {
    final next = _writes.then((_) {
      final json = <String, dynamic>{};
      for (final entry in _cache.entries) {
        json[entry.key] = entry.value.toJson();
      }
      return _file.writeAsString(jsonEncode(json));
    });
    _writes = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<DhikrCounterState?> get(String dhikrId) async {
    await _ensureLoaded();
    return _cache[dhikrId];
  }

  @override
  Future<void> increment(String dhikrId, {required int target}) async {
    await _ensureLoaded();

    final current = _cache[dhikrId];
    if (current == null) {
      _cache[dhikrId] = DhikrCounterState(
        dhikrId: dhikrId,
        count: 1,
        target: target,
      );
    } else {
      _cache[dhikrId] = current.increment();
    }

    await _save();
  }

  @override
  Future<void> decrement(String dhikrId) async {
    await _ensureLoaded();

    final current = _cache[dhikrId];
    if (current != null && current.count > 0) {
      _cache[dhikrId] = current.decrement();
      await _save();
    }
  }

  @override
  Future<void> reset(String dhikrId) async {
    await _ensureLoaded();

    final current = _cache[dhikrId];
    if (current != null) {
      _cache[dhikrId] = current.reset();
      await _save();
    }
  }

  @override
  Future<void> setTarget(String dhikrId, int target) async {
    await _ensureLoaded();

    final current = _cache[dhikrId];
    if (current != null) {
      _cache[dhikrId] = current.copyWith(target: target);
      await _save();
    } else {
      _cache[dhikrId] = DhikrCounterState(
        dhikrId: dhikrId,
        count: 0,
        target: target,
      );
      await _save();
    }
  }
}

/// Memory-only store for testing.
final class MemoryDhikrCounterStore implements DhikrCounterStore {
  final Map<String, DhikrCounterState> _data = {};

  @override
  Future<DhikrCounterState?> get(String dhikrId) async => _data[dhikrId];

  @override
  Future<void> increment(String dhikrId, {required int target}) async {
    final current = _data[dhikrId];
    if (current == null) {
      _data[dhikrId] = DhikrCounterState(
        dhikrId: dhikrId,
        count: 1,
        target: target,
      );
    } else {
      _data[dhikrId] = current.increment();
    }
  }

  @override
  Future<void> decrement(String dhikrId) async {
    final current = _data[dhikrId];
    if (current != null && current.count > 0) {
      _data[dhikrId] = current.decrement();
    }
  }

  @override
  Future<void> reset(String dhikrId) async {
    final current = _data[dhikrId];
    if (current != null) {
      _data[dhikrId] = current.reset();
    }
  }

  @override
  Future<void> setTarget(String dhikrId, int target) async {
    final current = _data[dhikrId];
    if (current != null) {
      _data[dhikrId] = current.copyWith(target: target);
    } else {
      _data[dhikrId] = DhikrCounterState(
        dhikrId: dhikrId,
        count: 0,
        target: target,
      );
    }
  }
}
