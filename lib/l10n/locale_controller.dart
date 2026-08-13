import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the user's language choice (`en` / `id`). Empty = follow system.
abstract interface class LocaleStore {
  Future<String?> readCode();

  Future<void> writeCode(String? code);
}

final class FileLocaleStore implements LocaleStore {
  FileLocaleStore(this._file);

  final File _file;

  @override
  Future<String?> readCode() async {
    if (!await _file.exists()) return null;
    try {
      final raw = (await _file.readAsString()).trim();
      if (raw == 'en' || raw == 'id') return raw;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCode(String? code) async {
    await _file.parent.create(recursive: true);
    if (code == null || code.isEmpty) {
      if (await _file.exists()) await _file.delete();
      return;
    }
    await _file.writeAsString('$code\n');
  }
}

final class MemoryLocaleStore implements LocaleStore {
  MemoryLocaleStore([this._code]);

  String? _code;

  @override
  Future<String?> readCode() async => _code;

  @override
  Future<void> writeCode(String? code) async => _code = code;
}

final localeStoreProvider = Provider<LocaleStore>((ref) {
  throw UnimplementedError('localeStoreProvider must be overridden');
});

/// Current app locale override. Null means system resolution (id/en only).
final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, Locale?>((ref) {
  return AppLocaleController(ref.watch(localeStoreProvider));
});

final class AppLocaleController extends StateNotifier<Locale?> {
  AppLocaleController(this._store) : super(null) {
    _load();
  }

  final LocaleStore _store;

  Future<void> _load() async {
    final code = await _store.readCode();
    if (code == null) {
      state = null;
      return;
    }
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _store.writeCode(locale.languageCode);
  }
}
