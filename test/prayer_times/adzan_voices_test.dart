import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/adzan_voices.dart';

void main() {
  test('catalog lists bundled reciter recordings by stable id', () {
    const expected = <String, String>{
      'ahmed_al_haddad': 'Ahmed Al-Haddad',
      'mansur_al_zahrane': 'Mansur Al Zahrane',
      'mishary_rashid_alafasy': 'Mishary Rashid Alafasy',
      'mishary_rashid_alafasy_fajr': 'Mishary Rashid Alafasy - Fajr',
      'muhammad_ramadan_saad': 'Muhammad Ramadan Saad',
      'nurdin_hamza_al_maghriby': 'NurDin Hamza Al Maghriby',
      'ali_ibn_ahmad_mala': 'Ali ibn Ahmad Mala',
    };

    for (final entry in expected.entries) {
      expect(AdzanVoices.byId(entry.key)?.displayName, entry.value);
      expect(AdzanVoices.all.any((voice) => voice.id == entry.key), isTrue);
    }

    expect(AdzanVoices.byId('fajr_adhan')?.id, 'fajr_adhan');
    expect(AdzanVoices.byId('standard_adhan')?.id, 'standard_adhan');
    expect(AdzanVoices.defaultForPrayer('fajr'), 'fajr_adhan');
    expect(AdzanVoices.defaultForPrayer('dhuhr'), 'standard_adhan');
  });
}
