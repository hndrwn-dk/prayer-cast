import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/launch_prayer.dart';

void main() {
  test('second launch of the same prayer within the window is a duplicate', () {
    final t0 = DateTime.utc(2026, 8, 18, 5, 0);
    expect(
      isDuplicateLaunchPrayer(
        prayer: 'dhuhr',
        previousPrayer: 'dhuhr',
        previousAt: t0,
        now: t0.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('a later prayer or a later window is not a duplicate', () {
    final t0 = DateTime.utc(2026, 8, 18, 5, 0);
    expect(
      isDuplicateLaunchPrayer(
        prayer: 'asr',
        previousPrayer: 'dhuhr',
        previousAt: t0,
        now: t0.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      isDuplicateLaunchPrayer(
        prayer: 'dhuhr',
        previousPrayer: 'dhuhr',
        previousAt: t0,
        now: t0.add(const Duration(seconds: 9)),
      ),
      isFalse,
    );
    expect(
      isDuplicateLaunchPrayer(
        prayer: 'dhuhr',
        previousPrayer: null,
        previousAt: null,
        now: t0,
      ),
      isFalse,
    );
  });
}
