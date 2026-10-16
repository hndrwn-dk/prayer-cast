import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';

void main() {
  group('FileAdhkarPrefs', () {
    late Directory tempDir;
    late File prefsFile;
    late FileAdhkarPrefs prefs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('adhkar_prefs_test');
      prefsFile = File('${tempDir.path}/adhkar_prefs.txt');
      prefs = FileAdhkarPrefs(prefsFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads defaults when file missing', () async {
      expect(prefs.enabled(AdhkarType.morning), false);
      expect(prefs.enabled(AdhkarType.evening), false);
      expect(prefs.delayMinutes(AdhkarType.morning), 10);
      expect(prefs.delayMinutes(AdhkarType.evening), 5);
    });

    test('saves and loads enabled state', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      await prefs.save();

      final loaded = FileAdhkarPrefs(prefsFile);
      await loaded.load();
      expect(loaded.enabled(AdhkarType.morning), true);
      expect(loaded.enabled(AdhkarType.evening), false);
    });

    test('saves and loads delay minutes', () async {
      await prefs.setDelayMinutes(AdhkarType.morning, 15);
      await prefs.setDelayMinutes(AdhkarType.evening, 10);
      await prefs.save();

      final loaded = FileAdhkarPrefs(prefsFile);
      await loaded.load();
      expect(loaded.delayMinutes(AdhkarType.morning), 15);
      expect(loaded.delayMinutes(AdhkarType.evening), 10);
    });

    test('persists multiple changes', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      await prefs.setDelayMinutes(AdhkarType.morning, 20);
      await prefs.setEnabled(AdhkarType.evening, true);
      await prefs.save();

      final loaded = FileAdhkarPrefs(prefsFile);
      await loaded.load();
      expect(loaded.enabled(AdhkarType.morning), true);
      expect(loaded.delayMinutes(AdhkarType.morning), 20);
      expect(loaded.enabled(AdhkarType.evening), true);
    });

    test('rejects out-of-range delay', () async {
      expect(
        () => prefs.setDelayMinutes(AdhkarType.morning, 121),
        throwsArgumentError,
      );
      expect(prefs.delayMinutes(AdhkarType.morning), 10);
    });

    test('handles malformed file gracefully', () async {
      await prefsFile.writeAsString('invalid=content\ngarbage');
      final loaded = FileAdhkarPrefs(prefsFile);
      await loaded.load();
      // Should fall back to defaults
      expect(loaded.enabled(AdhkarType.morning), false);
    });
  });
}
