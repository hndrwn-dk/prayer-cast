import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/theme/app_theme_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_theme_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('missing file is system', () async {
    final store = FileAppThemeStore(File('${dir.path}/app_theme.txt'));
    expect(await store.read(), AppThemeChoice.system);
  });

  test('write forest then read forest', () async {
    final store = FileAppThemeStore(File('${dir.path}/app_theme.txt'));
    await store.write(AppThemeChoice.forest);
    expect(await store.read(), AppThemeChoice.forest);
  });

  test('themeModeFor maps forest to ThemeMode.dark', () {
    expect(themeModeFor(AppThemeChoice.forest), ThemeMode.dark);
    expect(themeModeFor(AppThemeChoice.light), ThemeMode.light);
    expect(themeModeFor(AppThemeChoice.system), ThemeMode.system);
  });
}
