import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/travel_schedule_refresher.dart';

void main() {
  test('refreshIfMoved rewrites city after a large move', () async {
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        latitude: 1.35,
        longitude: 103.82,
        travelScheduleUpdates: true,
      ),
    );
    final alarm = _FakeAlarm();
    final refresher = TravelScheduleRefresher(
      store: store,
      location: _FakeLocation(
        const ResolvedLocation(
          latitude: -6.2,
          longitude: 106.8,
          city: 'Jakarta',
          country: 'Indonesia',
          administrativeArea: 'Jakarta Pusat',
        ),
      ),
      exactAlarm: alarm,
    );

    expect(await refresher.refreshIfMoved(), isTrue);
    final read = await store.read();
    expect(read.city, 'Jakarta');
    expect(read.country, 'Indonesia');
    expect(alarm.enabled, isTrue);
  });

  test('refreshIfMoved is a no-op when still in the same city', () async {
    const here = ResolvedLocation(
      latitude: 1.351,
      longitude: 103.821,
      city: 'Singapore',
      country: 'Singapore',
    );
    final store = MemoryPrayerPrefsStore(
      const PrayerPrefs(
        city: 'Singapore',
        country: 'Singapore',
        methodId: 11,
        madhabId: PrayerMadhabId.shafi,
        voiceId: 'standard_adhan',
        configured: true,
        latitude: 1.35,
        longitude: 103.82,
        travelScheduleUpdates: true,
      ),
    );
    final refresher = TravelScheduleRefresher(
      store: store,
      location: _FakeLocation(here),
      exactAlarm: _FakeAlarm(),
    );
    expect(await refresher.refreshIfMoved(), isFalse);
    expect((await store.read()).city, 'Singapore');
  });
}

final class _FakeLocation implements LocationResolving {
  _FakeLocation(this.resolved);

  final ResolvedLocation resolved;

  @override
  Future<bool> hasGrantedPermission() async => true;

  @override
  Future<ResolvedLocation> resolveCurrent() async => resolved;
}

final class _FakeAlarm implements ExactAlarmPlatform {
  bool? enabled;

  @override
  Future<void> syncTravelLocation({
    required bool enabled,
    double? latitude,
    double? longitude,
  }) async {
    this.enabled = enabled;
  }

  @override
  Stream<AlarmFiredEvent> get onFired => const Stream.empty();

  @override
  Stream<void> get onStopLocalPlayback => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> cancelPreAlert() async {}

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> playLocalBeep() async {}

  @override
  Future<void> playLocalTakbir() async {}

  @override
  Future<ScheduledAlarm?> readScheduled() async => null;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  }) async {}

  @override
  Future<void> schedulePreAlert({
    required int epochMs,
    required String title,
    required String body,
    String sound = 'beep',
  }) async {}

  @override
  Future<void> showDeliveryFailureNotification({
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showPhonePlaybackControls({required String prayer}) async {}

  @override
  Future<void> stopForegroundService() async {}
}
