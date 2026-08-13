import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

void main() {
  test('FilePrayerPrefsStore round-trips lat/lng', () async {
    final dir = await Directory.systemTemp.createTemp('prayer_prefs_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/prefs.txt');
    final store = FilePrayerPrefsStore(file);

    await store.write(
      const PrayerPrefs(
        city: 'Jakarta',
        country: 'Indonesia',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        latitude: -6.2088,
        longitude: 106.8456,
        voicesByPrayer: {'fajr': 'fajr_adhan'},
      ),
    );

    final read = await store.read();
    expect(read.city, 'Jakarta');
    expect(read.country, 'Indonesia');
    expect(read.hasCoordinates, isTrue);
    expect(read.latitude, closeTo(-6.2088, 0.0001));
    expect(read.longitude, closeTo(106.8456, 0.0001));
    expect(read.voicesByPrayer['fajr'], 'fajr_adhan');
  });

  test('FilePrayerPrefsStore reads legacy file without coords', () async {
    final dir = await Directory.systemTemp.createTemp('prayer_prefs_legacy_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/prefs.txt');
    await file.writeAsString(
      'Singapore\nSingapore\n11\nshafi\nstandard_adhan\n1\nfajr=fajr_adhan\n',
    );
    final read = await FilePrayerPrefsStore(file).read();
    expect(read.city, 'Singapore');
    expect(read.hasCoordinates, isFalse);
    expect(read.latitude, isNull);
    expect(read.longitude, isNull);
  });

  test('copyWith clearCoordinates drops lat/lng', () {
    const prefs = PrayerPrefs(
      city: 'A',
      country: 'B',
      methodId: 11,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
      latitude: 1.3,
      longitude: 103.8,
    );
    final cleared = prefs.copyWith(city: 'C', clearCoordinates: true);
    expect(cleared.city, 'C');
    expect(cleared.hasCoordinates, isFalse);
  });

  test('missing deliveryByPrayer defaults every prayer to cast', () async {
    final dir = await Directory.systemTemp.createTemp('prayer_prefs_nodel_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/prefs.txt');
    await file.writeAsString(
      'Singapore\nSingapore\n11\nshafi\nstandard_adhan\n1\n'
      'fajr=fajr_adhan\n1.3\n103.8\n',
    );
    final read = await FilePrayerPrefsStore(file).read();
    expect(read.deliveryByPrayer, isEmpty);
    for (final prayer in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      expect(read.deliveryFor(prayer), PrayerDeliveryMode.cast);
    }
  });

  test('FilePrayerPrefsStore round-trips per-prayer delivery modes', () async {
    final dir = await Directory.systemTemp.createTemp('prayer_prefs_del_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/prefs.txt');
    final store = FilePrayerPrefsStore(file);

    const original = PrayerPrefs(
      city: 'Singapore',
      country: 'Singapore',
      methodId: 11,
      madhabId: PrayerMadhabId.shafi,
      voiceId: 'standard_adhan',
      configured: true,
      voicesByPrayer: {'fajr': 'fajr_adhan'},
      deliveryByPrayer: {
        'fajr': 'beep',
        'dhuhr': 'adhanPhone',
        'asr': 'cast',
        'maghrib': 'beep',
        'isha': 'adhanPhone',
      },
    );
    await store.write(original);
    final read = await store.read();
    expect(read.deliveryFor('fajr'), PrayerDeliveryMode.beep);
    expect(read.deliveryFor('dhuhr'), PrayerDeliveryMode.adhanPhone);
    expect(read.deliveryFor('asr'), PrayerDeliveryMode.cast);
    expect(read.deliveryFor('maghrib'), PrayerDeliveryMode.beep);
    expect(read.deliveryFor('isha'), PrayerDeliveryMode.adhanPhone);

    final updated = read.withDeliveryFor('asr', PrayerDeliveryMode.beep);
    await store.write(updated);
    final reread = await store.read();
    expect(reread.deliveryFor('asr'), PrayerDeliveryMode.beep);
    expect(reread.deliveryFor('dhuhr'), PrayerDeliveryMode.adhanPhone);
  });

  test('unknown delivery wire values fall back to cast', () async {
    final dir = await Directory.systemTemp.createTemp('prayer_prefs_bad_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/prefs.txt');
    await file.writeAsString(
      'Singapore\nSingapore\n11\nshafi\nstandard_adhan\n1\n'
      'fajr=fajr_adhan\n\n\nfajr=trumpet,dhuhr=adhanPhone\n',
    );
    final read = await FilePrayerPrefsStore(file).read();
    expect(read.deliveryFor('fajr'), PrayerDeliveryMode.cast);
    expect(read.deliveryFor('dhuhr'), PrayerDeliveryMode.adhanPhone);
  });
}
