import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/active_delivery_hero.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/home_hero_prayer.dart';

void main() {
  final maghrib = NextPrayer(
    name: 'maghrib',
    scheduledAt: DateTime(2026, 9, 7, 19, 5),
    voiceId: 'standard_adhan',
  );
  final isha = NextPrayer(
    name: 'isha',
    scheduledAt: DateTime(2026, 9, 7, 20, 15),
    voiceId: 'standard_adhan',
  );

  group('resolveHomeHeroPrayer', () {
    test('prefers active delivery over upcoming', () {
      expect(
        resolveHomeHeroPrayer(active: maghrib, upcoming: isha),
        same(maghrib),
      );
    });

    test('falls back to upcoming when nothing is playing', () {
      expect(
        resolveHomeHeroPrayer(active: null, upcoming: isha),
        same(isha),
      );
    });

    test('null when neither active nor upcoming', () {
      expect(
        resolveHomeHeroPrayer(active: null, upcoming: null),
        isNull,
      );
    });
  });

  group('ActiveDeliveryHero', () {
    test('begin then clear notifies listeners', () {
      final hero = ActiveDeliveryHero();
      addTearDown(hero.dispose);
      final seen = <NextPrayer?>[];
      hero.listenable.addListener(() => seen.add(hero.current));

      hero.begin(maghrib);
      expect(hero.current, same(maghrib));
      hero.clear();
      expect(hero.current, isNull);
      expect(seen, [maghrib, null]);
    });
  });
}
