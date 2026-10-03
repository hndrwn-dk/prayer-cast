import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

void main() {
  test('missing file is not started', () async {
    final file = File(
      '${Directory.systemTemp.path}/onboarding_missing_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final record = await FileOnboardingStore(file).read();
    expect(record.step, isNull);
    expect(record.back, isNull);
  });

  test('round trip keeps step and back target', () async {
    final file = File(
      '${Directory.systemTemp.path}/onboarding_round_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final store = FileOnboardingStore(file);
    await store.write(
      const OnboardingRecord(
        step: OnboardingStep.phone,
        back: OnboardingStep.speaker,
      ),
    );
    final record = await store.read();
    expect(record.step, OnboardingStep.phone);
    expect(record.back, OnboardingStep.speaker);
  });
}
