import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeChoice { system, forest, light }

ThemeMode themeModeFor(AppThemeChoice choice) => switch (choice) {
  AppThemeChoice.system => ThemeMode.system,
  AppThemeChoice.forest => ThemeMode.dark,
  AppThemeChoice.light => ThemeMode.light,
};

abstract interface class AppThemeStore {
  Future<AppThemeChoice> read();

  Future<void> write(AppThemeChoice choice);
}

final class FileAppThemeStore implements AppThemeStore {
  FileAppThemeStore(this._file);

  final File _file;

  @override
  Future<AppThemeChoice> read() async {
    if (!await _file.exists()) return AppThemeChoice.system;
    try {
      final raw = (await _file.readAsString()).trim();
      return switch (raw) {
        'system' => AppThemeChoice.system,
        'forest' => AppThemeChoice.forest,
        'light' => AppThemeChoice.light,
        _ => AppThemeChoice.system,
      };
    } catch (_) {
      return AppThemeChoice.system;
    }
  }

  @override
  Future<void> write(AppThemeChoice choice) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString('${choice.name}\n');
  }
}

final class MemoryAppThemeStore implements AppThemeStore {
  MemoryAppThemeStore([this._choice = AppThemeChoice.system]);

  AppThemeChoice _choice;

  @override
  Future<AppThemeChoice> read() async => _choice;

  @override
  Future<void> write(AppThemeChoice choice) async => _choice = choice;
}

final appThemeStoreProvider = Provider<AppThemeStore>((ref) {
  throw UnimplementedError('appThemeStoreProvider must be overridden');
});

final appThemeProvider =
    StateNotifierProvider<AppThemeController, AppThemeChoice>((ref) {
      return AppThemeController(ref.watch(appThemeStoreProvider));
    });

final class AppThemeController extends StateNotifier<AppThemeChoice> {
  AppThemeController(this._store) : super(AppThemeChoice.system) {
    _load();
  }

  final AppThemeStore _store;

  Future<void> _load() async {
    state = await _store.read();
  }

  Future<void> setChoice(AppThemeChoice choice) async {
    state = choice;
    await _store.write(choice);
  }
}
