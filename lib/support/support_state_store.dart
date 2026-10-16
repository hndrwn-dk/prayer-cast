import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:prayer_cast/support/support_prompt_policy.dart';

/// File-backed prompt state (`support_state.json` in app documents).
abstract class SupportStateStore {
  Future<SupportPromptState> read();

  Future<void> write(SupportPromptState state);

  Stream<SupportPromptState> get changes;

  /// Keeps the later of the stored time and [at].
  Future<void> recordPurchase(DateTime at) async {
    final current = await read();
    final existing = current.lastPurchaseAt;
    if (existing != null && !at.isAfter(existing)) return;
    await write(current.copyWith(lastPurchaseAt: at));
  }
}

final class FileSupportStateStore extends SupportStateStore {
  FileSupportStateStore(this._file);

  final File _file;
  final StreamController<SupportPromptState> _changes =
      StreamController<SupportPromptState>.broadcast();

  SupportPromptState? _cached;
  bool _loaded = false;
  bool _loadFailed = false;

  @override
  Stream<SupportPromptState> get changes => _changes.stream;

  @override
  Future<SupportPromptState> read() async {
    if (_loaded) return _cached ?? const SupportPromptState();
    _loaded = true;
    if (!await _file.exists()) {
      _cached = const SupportPromptState();
      return _cached!;
    }
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) {
        _loadFailed = true;
        _cached = const SupportPromptState();
        return _cached!;
      }
      _cached = SupportPromptState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      return _cached!;
    } catch (_) {
      // Refuse later writes so a partial read cannot wipe the file.
      _loadFailed = true;
      _cached = const SupportPromptState();
      return _cached!;
    }
  }

  @override
  Future<void> write(SupportPromptState state) async {
    if (_loadFailed) return;
    _cached = state;
    _loaded = true;
    await _file.parent.create(recursive: true);
    final encoded = jsonEncode(state.toJson());
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    try {
      if (await _file.exists()) {
        await tmp.rename(_file.path);
      } else {
        await _file.writeAsString(encoded, flush: true);
        if (await tmp.exists()) await tmp.delete();
      }
    } catch (_) {
      await _file.writeAsString(encoded, flush: true);
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
    if (!_changes.isClosed) _changes.add(state);
  }
}

final class MemorySupportStateStore extends SupportStateStore {
  MemorySupportStateStore([SupportPromptState initial = const SupportPromptState()])
    : _state = initial;

  SupportPromptState _state;
  final StreamController<SupportPromptState> _changes =
      StreamController<SupportPromptState>.broadcast();

  @override
  Stream<SupportPromptState> get changes => _changes.stream;

  @override
  Future<SupportPromptState> read() async => _state;

  @override
  Future<void> write(SupportPromptState state) async {
    _state = state;
    if (!_changes.isClosed) _changes.add(state);
  }
}
