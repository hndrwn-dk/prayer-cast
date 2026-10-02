import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/setup/setup_card_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup_card_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('missing file reads as all-false flags', () async {
    final store = FileSetupCardStore(File('${dir.path}/setup_card.txt'));
    final flags = await store.read();
    expect(flags.dismissed, isFalse);
    expect(flags.noSpeaker, isFalse);
    expect(flags.remindersSeen, isFalse);
    expect(flags.existingUserMigrated, isFalse);
  });

  test('write then read round-trips flags', () async {
    final store = FileSetupCardStore(File('${dir.path}/setup_card.txt'));
    await store.write(
      const SetupCardFlags(
        dismissed: true,
        noSpeaker: true,
        remindersSeen: true,
        existingUserMigrated: true,
      ),
    );
    final flags = await store.read();
    expect(flags.dismissed, isTrue);
    expect(flags.noSpeaker, isTrue);
    expect(flags.remindersSeen, isTrue);
    expect(flags.existingUserMigrated, isTrue);
  });
}
