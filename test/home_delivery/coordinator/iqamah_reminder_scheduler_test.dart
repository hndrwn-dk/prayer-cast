import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/iqamah_reminder_scheduler.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

void main() {
  test('iqamah defaults Maghrib 5 / others 10', () {
    const prefs = PrayerPrefs.defaults;
    expect(prefs.iqamahMinutesFor('maghrib'), 5);
    expect(prefs.iqamahMinutesFor('fajr'), 10);
    expect(prefs.iqamahSound, IqamahSound.chime);
  });

  test('syncForPrayer schedules azan + offset with global sound', () async {
    final alarm = _RecordingExactAlarm();
    final store = MemoryPrayerPrefsStore(
      PrayerPrefs.defaults.copyWith(
        iqamahMinutesByPrayer: {
          'fajr': 10,
          'dhuhr': 10,
          'asr': 10,
          'maghrib': 5,
          'isha': 10,
        },
        iqamahSound: IqamahSound.silent,
      ),
    );
    final scheduler = IqamahReminderScheduler(
      exactAlarm: alarm,
      prayerPrefs: store,
      readLocaleCode: () async => 'en',
    );
    final azan = DateTime.utc(2026, 9, 9, 12, 0);
    await scheduler.syncForPrayer(
      NextPrayer(name: 'maghrib', scheduledAt: azan, voiceId: 'standard_adhan'),
      azan.subtract(const Duration(hours: 1)),
    );
    expect(alarm.scheduledEpochMs, azan.add(const Duration(minutes: 5))
        .millisecondsSinceEpoch);
    expect(alarm.sound, 'silent');
    expect(alarm.title, contains('Maghrib'));
  });

  test('zero minutes cancels iqamah', () async {
    final alarm = _RecordingExactAlarm();
    final store = MemoryPrayerPrefsStore(
      PrayerPrefs.defaults.withIqamahMinutesFor('fajr', 0),
    );
    final scheduler = IqamahReminderScheduler(
      exactAlarm: alarm,
      prayerPrefs: store,
      readLocaleCode: () async => 'en',
    );
    final azan = DateTime.utc(2026, 9, 9, 5, 0);
    await scheduler.syncForPrayer(
      NextPrayer(name: 'fajr', scheduledAt: azan, voiceId: 'fajr_adhan'),
      azan.subtract(const Duration(hours: 1)),
    );
    expect(alarm.cancelled, isTrue);
    expect(alarm.scheduledEpochMs, isNull);
  });
}

final class _RecordingExactAlarm implements ExactAlarmPlatform {
  int? scheduledEpochMs;
  String? title;
  String? sound;
  String? prayer;
  bool cancelled = false;

  @override
  Future<void> scheduleIqamahReminder({
    required int epochMs,
    required String title,
    required String body,
    required String prayer,
    String sound = 'chime',
  }) async {
    scheduledEpochMs = epochMs;
    this.title = title;
    this.sound = sound;
    this.prayer = prayer;
  }

  @override
  Future<void> cancelIqamahReminder() async {
    cancelled = true;
    scheduledEpochMs = null;
  }

  @override
  Future<List<PendingIqamahLog>> drainPendingIqamahLogs() async => const [];

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
