import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final class SetupCardFlags {
  const SetupCardFlags({
    this.dismissed = false,
    this.noSpeaker = false,
    this.remindersSeen = false,
    this.existingUserMigrated = false,
  });

  final bool dismissed;
  final bool noSpeaker;
  final bool remindersSeen;
  final bool existingUserMigrated;

  SetupCardFlags copyWith({
    bool? dismissed,
    bool? noSpeaker,
    bool? remindersSeen,
    bool? existingUserMigrated,
  }) {
    return SetupCardFlags(
      dismissed: dismissed ?? this.dismissed,
      noSpeaker: noSpeaker ?? this.noSpeaker,
      remindersSeen: remindersSeen ?? this.remindersSeen,
      existingUserMigrated:
          existingUserMigrated ?? this.existingUserMigrated,
    );
  }
}

abstract interface class SetupCardStore {
  Future<SetupCardFlags> read();

  Future<void> write(SetupCardFlags flags);
}

final class FileSetupCardStore implements SetupCardStore {
  FileSetupCardStore(this._file);

  final File _file;

  static const _defaults = SetupCardFlags();

  @override
  Future<SetupCardFlags> read() async {
    if (!await _file.exists()) return _defaults;
    try {
      final lines = (await _file.readAsLines())
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.length < 4) return _defaults;
      return SetupCardFlags(
        dismissed: _parseFlag(lines[0]),
        noSpeaker: _parseFlag(lines[1]),
        remindersSeen: _parseFlag(lines[2]),
        existingUserMigrated: _parseFlag(lines[3]),
      );
    } catch (_) {
      return _defaults;
    }
  }

  bool _parseFlag(String line) => line == '1';

  @override
  Future<void> write(SetupCardFlags flags) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      '${_formatFlag(flags.dismissed)}\n'
      '${_formatFlag(flags.noSpeaker)}\n'
      '${_formatFlag(flags.remindersSeen)}\n'
      '${_formatFlag(flags.existingUserMigrated)}\n',
    );
  }

  String _formatFlag(bool value) => value ? '1' : '0';
}

final class MemorySetupCardStore implements SetupCardStore {
  MemorySetupCardStore([this._flags = const SetupCardFlags()]);

  SetupCardFlags _flags;

  @override
  Future<SetupCardFlags> read() async => _flags;

  @override
  Future<void> write(SetupCardFlags flags) async => _flags = flags;
}

final setupCardStoreProvider = Provider<SetupCardStore>((ref) {
  throw UnimplementedError('setupCardStoreProvider must be overridden');
});
