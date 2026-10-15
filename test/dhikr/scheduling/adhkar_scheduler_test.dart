import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_scheduler.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

void main() {
  group('AdhkarScheduler', () {
    late MemoryAdhkarPrefs prefs;
    late AdhkarScheduler scheduler;

    final fajr = DateTime(2026, 10, 14, 5, 30);
    final dhuhr = DateTime(2026, 10, 14, 12, 15);
    final asr = DateTime(2026, 10, 14, 15, 45);
    final isha = DateTime(2026, 10, 14, 19, 30);

    setUp(() {
      prefs = MemoryAdhkarPrefs();
      scheduler = AdhkarScheduler(prefs);
    });

    test('is a PrayerTimeAdhkarScheduler by default', () {
      expect(scheduler, isA<PrayerTimeAdhkarScheduler>());
    });

    test('morning time is Fajr plus default 10 minute delay', () {
      expect(
        scheduler.calculateAdhkarTime(AdhkarType.morning, fajr),
        DateTime(2026, 10, 14, 5, 40),
      );
    });

    test('evening time is Asr plus default 5 minute delay', () {
      expect(
        scheduler.calculateAdhkarTime(AdhkarType.evening, asr),
        DateTime(2026, 10, 14, 15, 50),
      );
    });

    test('uses custom delay from prefs', () async {
      await prefs.setDelayMinutes(AdhkarType.morning, 20);
      expect(
        scheduler.calculateAdhkarTime(AdhkarType.morning, fajr),
        DateTime(2026, 10, 14, 5, 50),
      );
    });

    test('schedules enabled adhkar only', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      final scheduled = scheduler.getScheduledAdhkar({
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'isha': isha,
      });
      expect(scheduled.keys, [AdhkarType.morning]);
      expect(scheduled[AdhkarType.morning], DateTime(2026, 10, 14, 5, 40));
    });

    test('schedules both when both enabled', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      await prefs.setEnabled(AdhkarType.evening, true);
      final scheduled = scheduler.getScheduledAdhkar({
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'isha': isha,
      });
      expect(scheduled.length, 2);
      expect(scheduled[AdhkarType.evening], DateTime(2026, 10, 14, 15, 50));
    });

    test('returns empty when required prayer time missing', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      await prefs.setEnabled(AdhkarType.evening, true);
      expect(scheduler.getScheduledAdhkar({'dhuhr': dhuhr}), isEmpty);
      expect(scheduler.getScheduledAdhkar({}), isEmpty);
    });

    test('schedules without deadline when validity prayer is absent', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      final scheduled = scheduler.getScheduledAdhkar({'fajr': fajr});
      expect(scheduled.containsKey(AdhkarType.morning), true);
    });

    test('skips morning when delay pushes it too close to Dhuhr', () async {
      await prefs.setEnabled(AdhkarType.morning, true);
      await prefs.setDelayMinutes(AdhkarType.morning, 120);
      final earlyDhuhr = DateTime(2026, 10, 14, 7, 0);
      expect(
        scheduler.getScheduledAdhkar({'fajr': fajr, 'dhuhr': earlyDhuhr}),
        isEmpty,
      );
    });

    test('evening is valid until Isha, not Maghrib', () async {
      await prefs.setEnabled(AdhkarType.evening, true);
      final scheduled = scheduler.getScheduledAdhkar({
        'asr': asr,
        'maghrib': DateTime(2026, 10, 14, 16, 0),
        'isha': isha,
      });
      expect(scheduled.containsKey(AdhkarType.evening), true);
    });

    test('skips evening when too close to Isha', () async {
      await prefs.setEnabled(AdhkarType.evening, true);
      final lateAsr = DateTime(2026, 10, 14, 19, 0);
      expect(
        scheduler.getScheduledAdhkar({'asr': lateAsr, 'isha': isha}),
        isEmpty,
      );
    });

    test('delay 5 and iqamah 20 plays at Asr plus 30', () async {
      await prefs.setDelayMinutes(AdhkarType.evening, 5);
      final withIqamah = AdhkarScheduler(
        prefs,
        prayerPrefs: _prayerPrefs(asr: 20),
      );
      expect(
        withIqamah.calculateAdhkarTime(AdhkarType.evening, asr),
        DateTime(2026, 10, 14, 16, 15),
      );
      expect(
        (withIqamah as PrayerTimeAdhkarScheduler).iqamahOffsetWins(
          AdhkarType.evening,
        ),
        isTrue,
      );
    });

    test('delay 40 and iqamah 20 plays at Asr plus 40', () async {
      await prefs.setDelayMinutes(AdhkarType.evening, 40);
      final withIqamah = AdhkarScheduler(
        prefs,
        prayerPrefs: _prayerPrefs(asr: 20),
      );
      expect(
        withIqamah.calculateAdhkarTime(AdhkarType.evening, asr),
        DateTime(2026, 10, 14, 16, 25),
      );
      expect(
        (withIqamah as PrayerTimeAdhkarScheduler).iqamahOffsetWins(
          AdhkarType.evening,
        ),
        isFalse,
      );
    });

    test('iqamah off keeps the delay', () async {
      await prefs.setDelayMinutes(AdhkarType.evening, 12);
      final off = AdhkarScheduler(prefs, prayerPrefs: _prayerPrefs(asr: 0));
      expect(
        off.calculateAdhkarTime(AdhkarType.evening, asr),
        DateTime(2026, 10, 14, 15, 57),
      );
      expect(
        (off as PrayerTimeAdhkarScheduler).iqamahOffsetWins(AdhkarType.evening),
        isFalse,
      );
    });

    test('shouldSkipAdhkar boundaries', () {
      final t = DateTime(2026, 10, 14, 7, 0);
      expect(
        scheduler.shouldSkipAdhkar(t, t.add(const Duration(minutes: 29))),
        true,
      );
      expect(
        scheduler.shouldSkipAdhkar(t, t.add(const Duration(minutes: 30))),
        false,
      );
      expect(
        scheduler.shouldSkipAdhkar(t, t.subtract(const Duration(minutes: 1))),
        true,
      );
    });
  });
}

PrayerPrefs _prayerPrefs({required int asr}) {
  return PrayerPrefs(
    city: 'Singapore',
    country: 'Singapore',
    methodId: 11,
    madhabId: PrayerMadhabId.shafi,
    voiceId: 'standard_adhan',
    configured: true,
    iqamahMinutesByPrayer: {'asr': asr},
  );
}
