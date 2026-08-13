import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_device_kind.dart';

void main() {
  group('looksLikeTvCastTarget', () {
    test('hides Living Room TV and Android TV names', () {
      expect(looksLikeTvCastTarget('Living Room TV'), isTrue);
      expect(looksLikeTvCastTarget('Bedroom Television'), isTrue);
      expect(looksLikeTvCastTarget('Smart TV'), isTrue);
      expect(looksLikeTvCastTarget('Android TV'), isTrue);
      expect(looksLikeTvCastTarget('Office android tv'), isTrue);
    });

    test('hides plain Chromecast but keeps Chromecast Audio', () {
      expect(looksLikeTvCastTarget('Chromecast'), isTrue);
      expect(looksLikeTvCastTarget('Living Room Chromecast'), isTrue);
      expect(looksLikeTvCastTarget('Chromecast Audio'), isFalse);
      expect(looksLikeTvCastTarget('Chromecast Speaker'), isFalse);
    });

    test('keeps speakers, Nest, and groups', () {
      expect(looksLikeTvCastTarget('Kitchen Nest'), isFalse);
      expect(looksLikeTvCastTarget('Nest Mini'), isFalse);
      expect(looksLikeTvCastTarget('Nest Audio'), isFalse);
      expect(looksLikeTvCastTarget('Xiaomi Speaker'), isFalse);
      expect(looksLikeTvCastTarget('Speaker group'), isFalse);
      expect(looksLikeTvCastTarget('Living Room group'), isFalse);
      expect(looksLikeTvCastTarget('Upstairs speaker group'), isFalse);
    });

    test('group wins over TV-ish words in the same name', () {
      expect(looksLikeTvCastTarget('TV Room group'), isFalse);
    });
  });

  group('filterSpeakerCastTargets', () {
    test('filters to speakers only and preserves order', () {
      final names = [
        'Living Room TV',
        'Kitchen Nest',
        'Chromecast',
        'Speaker group',
        'Chromecast Audio',
      ];
      final kept = filterSpeakerCastTargets(names, (n) => n);
      expect(kept, ['Kitchen Nest', 'Speaker group', 'Chromecast Audio']);
    });
  });
}
