import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/adzan_voices.dart';

void main() {
  test('fajr catalog is only fajr recordings plus beep options', () {
    expect(
      AdzanVoices.forPrayer('fajr').map((v) => v.id).toList(),
      [
        'fajr_adhan',
        'fajr_mansur_al_zahrane',
        'fajr_mishary_rashid_alafasy',
        'beep',
        'long_beep',
      ],
    );
  });

  test('other prayers list standard voices plus beeps, without fajr', () {
    final ids = AdzanVoices.forPrayer('dhuhr').map((v) => v.id).toList();
    expect(ids, [
      'standard_adhan',
      'ahmed_al_haddad',
      'mishary_rashid_alafasy',
      'muhammad_ramadan_saad',
      'nurdin_hamza_al_maghriby',
      'ali_ibn_ahmad_mala',
      'beep',
      'long_beep',
    ]);
    expect(ids.any((id) => id.startsWith('fajr_')), isFalse);
    expect(ids, isNot(contains('makkah')));
  });

  test('defaults and legacy ids resolve to current assets', () {
    expect(AdzanVoices.defaultForPrayer('fajr'), 'fajr_adhan');
    expect(AdzanVoices.defaultForPrayer('dhuhr'), 'standard_adhan');
    expect(
      AdzanVoices.resolve('mishary_rashid_alafasy_fajr', prayerName: 'fajr'),
      'fajr_mishary_rashid_alafasy',
    );
    expect(
      AdzanVoices.resolve('mansur_al_zahrane', prayerName: 'fajr'),
      'fajr_mansur_al_zahrane',
    );
    expect(
      AdzanVoices.resolve('mansur_al_zahrane', prayerName: 'dhuhr'),
      'standard_adhan',
    );
    expect(
      AdzanVoices.resolve('makkah', prayerName: 'dhuhr'),
      'standard_adhan',
    );
    expect(AdzanVoices.byId('fajr_mansur_al_zahrane')?.displayName,
        'Mansur Al Zahrane - Fajr');
    expect(AdzanVoices.byId('makkah'), isNull);
  });
}
