import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/common/logger.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_audio_loader.dart';
import 'package:prayer_cast/home_delivery/coordinator/delivery_settings.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_orchestrator.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/platform/device_conditions.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/presence/presence_schedule.dart';

final class _FakeClock implements Clock {
  _FakeClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advanceTo(DateTime t) => _now = t;
}

final class _FakeExactAlarm implements ExactAlarmPlatform {
  final _fireController = StreamController<AlarmFiredEvent>.broadcast();
  final scheduled = <({int epochMs, String prayer, String voiceId})>[];
  final callOrder = <String>[];
  int stopForegroundCalls = 0;
  bool canSchedule = true;
  bool throwOnSchedule = false;

  @override
  Stream<AlarmFiredEvent> get onFired => _fireController.stream;

  @override
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  }) async {
    callOrder.add('scheduleNext');
    if (throwOnSchedule) {
      throw ExactAlarmFailure('scheduleNext failed for test');
    }
    scheduled
      ..clear()
      ..add((epochMs: epochMs, prayer: prayer, voiceId: voiceId));
  }

  @override
  Future<void> cancel() async {
    scheduled.clear();
  }

  @override
  Future<bool> canScheduleExactAlarms() async => canSchedule;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> stopForegroundService() async {
    callOrder.add('stopForegroundService');
    stopForegroundCalls += 1;
  }

  void emit(AlarmFiredEvent event) => _fireController.add(event);

  Future<void> dispose() => _fireController.close();
}

final class _FakeNextPrayer implements NextPrayerProvider {
  _FakeNextPrayer(this._prayers);
  final List<NextPrayer> _prayers;

  @override
  Future<NextPrayer> next({required DateTime after}) async {
    for (final p in _prayers) {
      if (p.scheduledAt.isAfter(after)) return p;
    }
    return NextPrayer(
      name: _prayers.first.name,
      scheduledAt: _prayers.last.scheduledAt.add(const Duration(days: 1)),
      voiceId: _prayers.first.voiceId,
    );
  }
}

final class _FakeSettings implements DeliverySettings {
  @override
  Future<String?> homeCastDeviceId() async => 'cast-home-1';

  @override
  Future<double> playbackVolume() async => 0.7;
}

final class _FakeAudio implements AdzanAudioLoader {
  @override
  Future<Uint8List> load(String voiceId) async =>
      Uint8List.fromList(List<int>.filled(32, 1));
}

final class _FakeConditions implements DeviceConditionsProvider {
  @override
  Future<DeviceConditions> current() async => const DeviceConditions(
        formFactor: DeviceFormFactor.phone,
        isPluggedIn: true,
        isScreenOn: true,
        batteryPercent: 80,
        batterySaverActive: false,
        clockSkewDetected: false,
      );
}

final class _RecordingLogger implements HomeDeliveryLogger {
  final warns = <String>[];

  @override
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}

  @override
  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    warns.add(message);
  }

  @override
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}
}

void main() {
  late _FakeClock clock;
  late _FakeExactAlarm alarm;
  late List<DeliveryRequest> deliveries;
  late DateTime t0;
  late NextPrayer maghrib;
  late NextPrayer isha;

  setUp(() {
    t0 = DateTime.utc(2026, 8, 10, 18, 0);
    clock = _FakeClock(t0);
    alarm = _FakeExactAlarm();
    deliveries = [];
    maghrib = NextPrayer(
      name: 'maghrib',
      scheduledAt: t0.add(const Duration(hours: 1)),
      voiceId: 'makkah',
    );
    isha = NextPrayer(
      name: 'isha',
      scheduledAt: t0.add(const Duration(hours: 2)),
      voiceId: 'madinah',
    );
  });

  tearDown(() async {
    await alarm.dispose();
  });

  PrayerDeliveryCoordinator buildCoordinator({
    bool Function()? canScheduleOverride,
    void Function(bool)? onPermission,
    HomeDeliveryLogger logger = const SilentLogger(),
  }) {
    if (canScheduleOverride != null) {
      alarm.canSchedule = canScheduleOverride();
    }
    return PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
      onPermissionChanged: onPermission,
      logger: logger,
    );
  }

  Future<void> fireAndSettle(
    PrayerDeliveryCoordinator coordinator, {
    required int wakeMs,
    String? voiceId = 'makkah',
    Completer<void>? deliveryDone,
  }) async {
    final done = deliveryDone ?? Completer<void>();
    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs + 50,
        voiceId: voiceId,
      ),
    );
    // Wait until stopForegroundService has run (end of _onFired).
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (!done.isCompleted && deliveries.isNotEmpty) {
      // delivery may have completed without our completer
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('start schedules wake = azan + PresenceSchedule.scanOffset with voiceId',
      () async {
    final coordinator = buildCoordinator();
    await coordinator.start();

    final expectedWake = maghrib.scheduledAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.epochMs, expectedWake);
    expect(alarm.scheduled.single.prayer, 'maghrib');
    expect(alarm.scheduled.single.voiceId, 'makkah');
    expect(coordinator.scheduledWakeEpochMs, expectedWake);
  });

  test('fire → orchestrator with reconstructed azanEpoch → reschedule next',
      () async {
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;
    alarm.callOrder.clear();

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs + 50,
        voiceId: 'makkah',
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, hasLength(1));
    final req = deliveries.single;
    expect(req.prayerName, 'maghrib');
    expect(req.scheduledAzan, maghrib.scheduledAt);
    expect(req.voiceId, 'makkah');
    expect(req.homeCastDeviceId, 'cast-home-1');
    expect(alarm.stopForegroundCalls, 1);

    // Exactly one alarm queued — now for isha with its voiceId.
    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.prayer, 'isha');
    expect(alarm.scheduled.single.voiceId, 'madinah');
    final ishaWake = isha.scheduledAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    expect(alarm.scheduled.single.epochMs, ishaWake);
    expect(coordinator.lastHandledWakeEpochMs, wakeMs);
  });

  test('scheduleNext runs before stopForegroundService on successful delivery',
      () async {
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;
    alarm.callOrder.clear();

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(alarm.callOrder, ['scheduleNext', 'stopForegroundService']);
  });

  test('stopForegroundService still runs when reschedule throws', () async {
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        // After first delivery, make the subsequent reschedule throw.
        alarm.throwOnSchedule = true;
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;
    alarm.callOrder.clear();

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(alarm.stopForegroundCalls, 1);
    expect(alarm.callOrder.last, 'stopForegroundService');
    expect(alarm.callOrder.contains('scheduleNext'), isTrue);
  });

  test('duplicate onFired for the same wake epoch is ignored', () async {
    final firstDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        if (!firstDone.isCompleted) firstDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;

    final event = AlarmFiredEvent(
      prayer: 'maghrib',
      scheduledEpochMs: wakeMs,
      firedAtMs: wakeMs,
      voiceId: 'makkah',
    );
    alarm.emit(event);
    await firstDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final stopsAfterFirst = alarm.stopForegroundCalls;
    alarm.emit(event);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(deliveries, hasLength(1));
    expect(alarm.stopForegroundCalls, stopsAfterFirst);
  });

  test('permission-denied path does not throw and exposes state', () async {
    final permissions = <bool>[];
    alarm.canSchedule = false;
    final coordinator = buildCoordinator(onPermission: permissions.add);

    await expectLater(coordinator.start(), completes);
    expect(permissions, [false]);
    expect(alarm.scheduled, isEmpty);
    expect(deliveries, isEmpty);
  });

  test(
    'retryScheduleAfterPermissionGranted arms wake after late grant',
    () async {
      final permissions = <bool>[];
      alarm.canSchedule = false;
      final coordinator = buildCoordinator(onPermission: permissions.add);
      await coordinator.start();
      expect(alarm.scheduled, isEmpty);

      // User grants SCHEDULE_EXACT_ALARM in system settings, then app resumes.
      alarm.canSchedule = true;
      await coordinator.retryScheduleAfterPermissionGranted();

      expect(permissions, [false, true]);
      expect(alarm.scheduled, hasLength(1));
      expect(alarm.scheduled.single.prayer, 'maghrib');
      expect(coordinator.scheduledWakeEpochMs, isNotNull);
    },
  );

  test(
    'retryScheduleAfterPermissionGranted is a no-op when already scheduled',
    () async {
      final coordinator = buildCoordinator();
      await coordinator.start();
      final first = List.of(alarm.scheduled);

      await coordinator.retryScheduleAfterPermissionGranted();
      expect(alarm.scheduled, first);
    },
  );

  test('missing voiceId logs warning and falls back to defaultVoiceId', () async {
    final logger = _RecordingLogger();
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
      logger: logger,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: '',
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries.single.voiceId, PrayerDeliveryCoordinator.defaultVoiceId);
    expect(
      logger.warns.any((m) => m.contains('missing voiceId')),
      isTrue,
    );
  });

  test('null voiceId logs warning and falls back to defaultVoiceId', () async {
    final logger = _RecordingLogger();
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      runDelivery: (request) async {
        deliveries.add(request);
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
      logger: logger,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: null,
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries.single.voiceId, PrayerDeliveryCoordinator.defaultVoiceId);
    expect(logger.warns, isNotEmpty);
  });

  test('StaticNextPrayerProvider returns prayers after the cursor', () async {
    final provider = StaticNextPrayerProvider(
      sequence: [maghrib, isha],
    );
    final next = await provider.next(after: t0);
    expect(next.name, 'maghrib');
    final afterMaghrib =
        await provider.next(after: maghrib.scheduledAt);
    expect(afterMaghrib.name, 'isha');
  });
}
