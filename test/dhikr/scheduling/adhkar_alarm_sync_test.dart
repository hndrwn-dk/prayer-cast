import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_alarm_sync.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

void main() {
  final asr = DateTime(2026, 10, 14, 15, 45);
  final isha = DateTime(2026, 10, 14, 19, 30);
  final fajr = DateTime(2026, 10, 14, 5, 30);
  final dhuhr = DateTime(2026, 10, 14, 12, 15);

  late MemoryAdhkarPrefs adhkarPrefs;
  late _RecordingAlarm alarm;
  late DateTime now;
  late PrayerPrefs prayerPrefs;

  setUp(() {
    adhkarPrefs = MemoryAdhkarPrefs();
    alarm = _RecordingAlarm();
    now = DateTime(2026, 10, 14, 10);
    prayerPrefs = _prefs();
  });

  AdhkarAlarmSync build() {
    return AdhkarAlarmSync(
      adhkarPrefs: adhkarPrefs,
      alarm: alarm,
      readPrayerPrefs: () async => prayerPrefs,
      readPrayerTimes: (day) async {
        if (day.day != 14 && day.day != 15) return null;
        final shift = day.day == 15 ? const Duration(days: 1) : Duration.zero;
        return {
          'fajr': fajr.add(shift),
          'dhuhr': dhuhr.add(shift),
          'asr': asr.add(shift),
          'isha': isha.add(shift),
        };
      },
      clock: () => now,
    );
  }

  test('delay 5 and iqamah 20 schedules evening at Asr plus 30', () async {
    await adhkarPrefs.setEnabled(AdhkarType.evening, true);
    await adhkarPrefs.setDelayMinutes(AdhkarType.evening, 5);
    prayerPrefs = _prefs(asr: 20);
    await build().sync();
    expect(
      alarm.scheduled['evening'],
      DateTime(2026, 10, 14, 16, 15).millisecondsSinceEpoch,
    );
    expect(alarm.cancelled, ['morning']);
  });

  test('delay 40 and iqamah 20 schedules evening at Asr plus 40', () async {
    await adhkarPrefs.setEnabled(AdhkarType.evening, true);
    await adhkarPrefs.setDelayMinutes(AdhkarType.evening, 40);
    prayerPrefs = _prefs(asr: 20);
    await build().sync();
    expect(
      alarm.scheduled['evening'],
      DateTime(2026, 10, 14, 16, 25).millisecondsSinceEpoch,
    );
  });

  test('iqamah off schedules evening at Asr plus the delay', () async {
    await adhkarPrefs.setEnabled(AdhkarType.evening, true);
    await adhkarPrefs.setDelayMinutes(AdhkarType.evening, 5);
    prayerPrefs = _prefs(asr: 0);
    await build().sync();
    expect(
      alarm.scheduled['evening'],
      DateTime(2026, 10, 14, 15, 50).millisecondsSinceEpoch,
    );
  });

  test('cancels a disabled type and arms an enabled one', () async {
    await adhkarPrefs.setEnabled(AdhkarType.morning, true);
    await build().sync();
    expect(alarm.scheduled.containsKey('morning'), isTrue);
    expect(alarm.cancelled, ['evening']);
    expect(
      alarm.scheduled['morning'],
      DateTime(2026, 10, 15, 5, 40).millisecondsSinceEpoch,
    );
  });

  test('arms tomorrow when today is already past', () async {
    await adhkarPrefs.setEnabled(AdhkarType.evening, true);
    await adhkarPrefs.setDelayMinutes(AdhkarType.evening, 5);
    prayerPrefs = _prefs(asr: 0);
    now = DateTime(2026, 10, 14, 18);
    await build().sync();
    expect(
      alarm.scheduled['evening'],
      DateTime(2026, 10, 15, 15, 50).millisecondsSinceEpoch,
    );
  });
}

PrayerPrefs _prefs({int asr = 0}) {
  return PrayerPrefs(
    city: 'Singapore',
    country: 'Singapore',
    methodId: 11,
    madhabId: PrayerMadhabId.shafi,
    voiceId: 'standard_adhan',
    configured: true,
    iqamahMinutesByPrayer: {'asr': asr, 'fajr': 0},
  );
}

final class _RecordingAlarm implements ExactAlarmPlatform {
  final scheduled = <String, int>{};
  final cancelled = <String>[];

  @override
  Future<void> scheduleAdhkar({required String type, required int atMs}) async {
    cancelled.remove(type);
    scheduled[type] = atMs;
  }

  @override
  Future<void> cancelAdhkar(String type) async {
    scheduled.remove(type);
    cancelled.add(type);
  }

  @override
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> stopForegroundService() async {}

  @override
  Future<void> showPhonePlaybackControls({required String prayer}) async {}

  @override
  Future<void> playLocalBeep() async {}

  @override
  Future<void> playLocalTakbir() async {}

  @override
  Future<void> syncTravelLocation({
    required bool enabled,
    double? latitude,
    double? longitude,
  }) async {}

  @override
  Future<ScheduledAlarm?> readScheduled() async => null;

  @override
  Future<void> schedulePreAlert({
    required int epochMs,
    required String title,
    required String body,
    String sound = 'beep',
  }) async {}

  @override
  Future<void> cancelPreAlert() async {}

  @override
  Future<void> scheduleIqamahReminder({
    required int epochMs,
    required String title,
    required String body,
    required String prayer,
    String sound = 'chime',
  }) async {}

  @override
  Future<void> cancelIqamahReminder() async {}

  @override
  Future<List<PendingIqamahLog>> drainPendingIqamahLogs() async => const [];

  @override
  Future<void> showDeliveryFailureNotification({
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> markDeliveryReady() async {}

  @override
  Future<void> acknowledgeAlarmFire() async {}

  @override
  Stream<AlarmFiredEvent> get onFired => const Stream.empty();

  @override
  Stream<void> get onStopLocalPlayback => const Stream.empty();
}
