import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OnboardingStep {
  audio,
  speaker,
  phone,
  prayer,
  notifications,
  alarm,
  battery,
  completed,
}

final class OnboardingRecord {
  const OnboardingRecord({this.step, this.back});

  /// Null means the file was missing: onboarding has not started.
  final OnboardingStep? step;
  final OnboardingStep? back;

  static const notStarted = OnboardingRecord();
}

abstract interface class OnboardingStore {
  Future<OnboardingRecord> read();
  Future<void> write(OnboardingRecord record);
}

final class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore([this._record = OnboardingRecord.notStarted]);

  OnboardingRecord _record;

  @override
  Future<OnboardingRecord> read() async => _record;

  @override
  Future<void> write(OnboardingRecord record) async => _record = record;
}

final class FileOnboardingStore implements OnboardingStore {
  FileOnboardingStore(this._file);

  final File _file;

  @override
  Future<OnboardingRecord> read() async {
    if (!await _file.exists()) return OnboardingRecord.notStarted;
    try {
      final lines = (await _file.readAsLines())
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) return OnboardingRecord.notStarted;
      return OnboardingRecord(
        step: _parse(lines[0]),
        back: lines.length > 1 ? _parse(lines[1]) : null,
      );
    } catch (_) {
      return OnboardingRecord.notStarted;
    }
  }

  OnboardingStep? _parse(String raw) {
    if (raw == '-') return null;
    for (final step in OnboardingStep.values) {
      if (step.name == raw) return step;
    }
    return null;
  }

  @override
  Future<void> write(OnboardingRecord record) async {
    await _file.parent.create(recursive: true);
    final step = record.step?.name ?? '-';
    final back = record.back?.name ?? '-';
    await _file.writeAsString('$step\n$back\n');
  }
}

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  throw UnimplementedError('onboardingStoreProvider must be overridden');
});
