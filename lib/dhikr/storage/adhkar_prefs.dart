import 'dart:io';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';

/// Storage for adhkar preferences (enabled state, timing delays).
abstract class AdhkarPrefs {
  bool enabled(AdhkarType type);
  int delayMinutes(AdhkarType type);
  Future<void> setEnabled(AdhkarType type, bool value);
  Future<void> setDelayMinutes(AdhkarType type, int minutes);
  Future<void> save();
  Future<void> load();
}

/// File-based adhkar preferences storage (pattern matches prayer_prefs.txt).
final class FileAdhkarPrefs implements AdhkarPrefs {
  FileAdhkarPrefs(this._file);

  final File _file;
  final Map<AdhkarType, bool> _enabled = {
    AdhkarType.morning: false,
    AdhkarType.evening: false,
  };
  final Map<AdhkarType, int> _delayMinutes = {
    AdhkarType.morning: 10,
    AdhkarType.evening: 5,
  };

  @override
  bool enabled(AdhkarType type) => _enabled[type] ?? false;

  @override
  int delayMinutes(AdhkarType type) => _delayMinutes[type] ?? 10;

  @override
  Future<void> setEnabled(AdhkarType type, bool value) async {
    _enabled[type] = value;
  }

  @override
  Future<void> setDelayMinutes(AdhkarType type, int minutes) async {
    if (minutes < 0 || minutes > 120) {
      throw ArgumentError('Delay must be between 0 and 120 minutes');
    }
    _delayMinutes[type] = minutes;
  }

  @override
  Future<void> save() async {
    final lines = <String>[];
    for (final type in AdhkarType.values) {
      lines.add('${type.name}_enabled=${_enabled[type] ?? false}');
      lines.add('${type.name}_delay_minutes=${_delayMinutes[type] ?? 10}');
    }
    await _file.writeAsString(lines.join('\n'));
  }

  @override
  Future<void> load() async {
    if (!await _file.exists()) return;

    try {
      final content = await _file.readAsString();
      final lines = content.split('\n');

      for (final line in lines) {
        if (line.isEmpty) continue;
        final parts = line.split('=');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final value = parts[1].trim();

        if (key.endsWith('_enabled')) {
          final typeName = key.replaceAll('_enabled', '');
          try {
            final type = AdhkarType.fromString(typeName);
            _enabled[type] = value.toLowerCase() == 'true';
          } catch (_) {
            // Invalid type, skip
          }
        } else if (key.endsWith('_delay_minutes')) {
          final typeName = key.replaceAll('_delay_minutes', '');
          try {
            final type = AdhkarType.fromString(typeName);
            final minutes = int.tryParse(value) ?? 10;
            _delayMinutes[type] = minutes;
          } catch (_) {
            // Invalid type or number, skip
          }
        }
      }
    } catch (_) {
      // File read error, keep defaults
    }
  }
}

/// Memory-only prefs for testing.
final class MemoryAdhkarPrefs implements AdhkarPrefs {
  final Map<AdhkarType, bool> _enabled = {
    AdhkarType.morning: false,
    AdhkarType.evening: false,
  };
  final Map<AdhkarType, int> _delayMinutes = {
    AdhkarType.morning: 10,
    AdhkarType.evening: 5,
  };

  @override
  bool enabled(AdhkarType type) => _enabled[type] ?? false;

  @override
  int delayMinutes(AdhkarType type) => _delayMinutes[type] ?? 10;

  @override
  Future<void> setEnabled(AdhkarType type, bool value) async {
    _enabled[type] = value;
  }

  @override
  Future<void> setDelayMinutes(AdhkarType type, int minutes) async {
    _delayMinutes[type] = minutes;
  }

  @override
  Future<void> save() async {}

  @override
  Future<void> load() async {}
}
