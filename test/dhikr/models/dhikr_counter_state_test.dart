import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';

void main() {
  DhikrCounterState make({int count = 0, int target = 33}) =>
      DhikrCounterState(dhikrId: 'subhanallah', count: count, target: target);

  group('DhikrCounterState', () {
    test('creates with given count and target', () {
      final state = make();
      expect(state.count, 0);
      expect(state.target, 33);
    });

    test('increments count', () {
      final newState = make(count: 5).increment();
      expect(newState.count, 6);
      expect(newState.dhikrId, 'subhanallah');
    });

    test('resets count to zero', () {
      final newState = make(count: 25).reset();
      expect(newState.count, 0);
      expect(newState.target, 33);
    });

    test('updates target', () {
      final newState = make(count: 10).copyWith(target: 100);
      expect(newState.target, 100);
      expect(newState.count, 10);
    });

    test('calculates progress', () {
      expect(make(count: 10, target: 100).progress, 0.1);
    });

    test('progress is 1.0 when count exceeds target', () {
      expect(make(count: 150, target: 100).progress, 1.0);
    });

    test('progress is 0 when target is zero', () {
      expect(make(count: 5, target: 0).progress, 0.0);
    });

    test('decrement undoes one tap and stops at zero', () {
      expect(make(count: 5).decrement().count, 4);
      expect(make(count: 0).decrement().count, 0);
    });

    test('isComplete once count reaches target', () {
      expect(make(count: 32).isComplete, false);
      expect(make(count: 33).isComplete, true);
      expect(make(count: 3, target: 0).isComplete, false);
    });

    test('converts to and from JSON', () {
      final state = DhikrCounterState(
        dhikrId: 'subhanallah',
        count: 42,
        target: 100,
        lastUpdated: DateTime(2026, 10, 14, 12, 30),
      );
      final decoded = DhikrCounterState.fromJson(state.toJson());

      expect(decoded.dhikrId, state.dhikrId);
      expect(decoded.count, state.count);
      expect(decoded.target, state.target);
      expect(decoded.lastUpdated, state.lastUpdated);
    });
  });
}
