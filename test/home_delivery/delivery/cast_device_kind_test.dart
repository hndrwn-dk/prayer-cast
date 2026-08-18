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

    test('hides common smart-TV brands and SKUs', () {
      const tvs = [
        'Samsung QN55Q80C',
        'AU8000 Living Room',
        'LG OLED55C3',
        'Sony XR-55A80L',
        'KD-55X80K',
        'Hisense U7K',
        'TCL 55C745',
        'Philips PUS8507',
        'The Frame',
        'Google TV Bedroom',
        'Chromecast with Google TV',
        'Roku TV',
        'Fire TV Stick',
        'Mi Box',
        'Xiaomi TV 55',
        'Bravia 65 inch',
        'LG 55NANO80',
        'Chromecast HD',
        'Chromecast Ultra',
        'Google Streamer',
        'Vizio Living Room',
        'Hisense A6H',
        'PRIMS Q55U',
        'Onn Google TV',
      ];
      for (final name in tvs) {
        expect(looksLikeTvCastTarget(name), isTrue, reason: name);
      }
    });

    test('keeps Nest Hub speakers but hides reported TVs', () {
      expect(looksLikeTvCastTarget('Master Room Display'), isFalse);
      expect(looksLikeTvCastTarget('Nest Hub'), isFalse);
      expect(looksLikeTvCastTarget('Google Nest Hub Max'), isFalse);
      expect(looksLikeTvCastTarget('Prism-Q55U'), isTrue);
    });

    test('keeps speakers, Nest, and groups', () {
      expect(looksLikeTvCastTarget('Living Room speaker'), isFalse);
      expect(looksLikeTvCastTarget('Boys Bedroom speaker'), isFalse);
      expect(looksLikeTvCastTarget('Azan Speaker'), isFalse);
      expect(looksLikeTvCastTarget('TV speaker'), isFalse);
      expect(looksLikeTvCastTarget('Kitchen Nest'), isFalse);
      expect(looksLikeTvCastTarget('Nest Mini'), isFalse);
      expect(looksLikeTvCastTarget('Nest Audio'), isFalse);
      expect(looksLikeTvCastTarget('Xiaomi Speaker'), isFalse);
      expect(looksLikeTvCastTarget('Speaker group'), isFalse);
      expect(looksLikeTvCastTarget('Living Room group'), isFalse);
      expect(looksLikeTvCastTarget('Upstairs speaker group'), isFalse);
      expect(looksLikeTvCastTarget('Samsung soundbar'), isFalse);
      expect(looksLikeTvCastTarget('Roku Streambar'), isFalse);
      expect(looksLikeTvCastTarget('Sonos Arc'), isFalse);
    });

    test('group wins over TV-ish words in the same name', () {
      expect(looksLikeTvCastTarget('TV Room group'), isFalse);
    });
  });

  group('looksLikeCastGroup', () {
    test('matches Google Home / Cast group names', () {
      expect(looksLikeCastGroup('Home group speaker'), isTrue);
      expect(looksLikeCastGroup('Speaker group'), isTrue);
      expect(looksLikeCastGroup('Living Room group'), isTrue);
      expect(looksLikeCastGroup('Bedroom speaker'), isFalse);
      expect(looksLikeCastGroup('Mi Smart Speaker'), isFalse);
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
        'Master Room Display',
        'Prism-Q55U',
        'Azan Speaker',
      ];
      final kept = filterSpeakerCastTargets(names, (n) => n);
      expect(
        kept,
        [
          'Kitchen Nest',
          'Speaker group',
          'Chromecast Audio',
          'Master Room Display',
          'Azan Speaker',
        ],
      );
    });
  });
}
