import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/hero_hold_timing.dart';

void main() {
  group('shouldEndHeroHoldOnFinished', () {
    test('ignores finished before min hold', () {
      expect(
        shouldEndHeroHoldOnFinished(
          elapsedSinceHoldBegan: const Duration(seconds: 15),
        ),
        isFalse,
      );
    });

    test('accepts finished after min hold', () {
      expect(
        shouldEndHeroHoldOnFinished(
          elapsedSinceHoldBegan: const Duration(minutes: 2, seconds: 30),
        ),
        isTrue,
      );
    });
  });
}
