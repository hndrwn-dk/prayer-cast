import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/adhan_countdown.dart';

void main() {
  group('AdhanCountdown.clock', () {
    test('formats under one hour as MM:SS', () {
      expect(AdhanCountdown.clock(const Duration(minutes: 53, seconds: 12)), '53:12');
      expect(AdhanCountdown.clock(const Duration(seconds: 9)), '00:09');
    });

    test('formats one hour and over as H:MM:SS', () {
      expect(
        AdhanCountdown.clock(const Duration(hours: 2, minutes: 5, seconds: 8)),
        '2:05:08',
      );
    });

    test('clamps negative remaining to 00:00', () {
      expect(AdhanCountdown.clock(const Duration(seconds: -3)), '00:00');
      expect(AdhanCountdown.isDue(const Duration(seconds: -1)), isTrue);
      expect(AdhanCountdown.isDue(Duration.zero), isTrue);
      expect(AdhanCountdown.isDue(const Duration(seconds: 1)), isFalse);
    });
  });
}
