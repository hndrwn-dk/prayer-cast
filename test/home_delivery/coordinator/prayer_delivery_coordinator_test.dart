import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/common/logger.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_audio_loader.dart';
import 'package:prayer_cast/home_delivery/coordinator/delivery_settings.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_mode_source.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_orchestrator.dart';
import 'package:prayer_cast/home_delivery/delivery/delivery_timing.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_log_dao.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/platform/device_conditions.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/presence/presence_schedule.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

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

  @override
  Future<void> showPhonePlaybackControls({required String prayer}) async {
    callOrder.add('showPhonePlaybackControls');
  }

  @override
  Future<void> playLocalBeep() async {
    callOrder.add('playLocalBeep');
  }

  @override
  Future<void> playLocalTakbir() async {
    callOrder.add('playLocalTakbir');
  }

  @override
  Future<void> syncTravelLocation({
    required bool enabled,
    double? latitude,
    double? longitude,
  }) async {}

  final _stopLocalPlayback = StreamController<void>.broadcast();

  @override
  Stream<void> get onStopLocalPlayback => _stopLocalPlayback.stream;

  void emitStopLocalPlayback() => _stopLocalPlayback.add(null);

  @override
  Future<ScheduledAlarm?> readScheduled() async {
    if (scheduled.isEmpty) return null;
    final s = scheduled.single;
    return ScheduledAlarm(
      epochMs: s.epochMs,
      prayer: s.prayer,
      voiceId: s.voiceId,
    );
  }

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

  void emit(AlarmFiredEvent event) => _fireController.add(event);

  Future<void> dispose() async {
    await _stopLocalPlayback.close();
    await _fireController.close();
  }
}

final class _CountingNextPrayer implements NextPrayerProvider {
  _CountingNextPrayer({
    required this.first,
    required this.afterFirst,
    this.onCall,
  });

  final NextPrayer first;
  final NextPrayer Function() afterFirst;
  final void Function()? onCall;

  int calls = 0;

  @override
  Future<NextPrayer> next({
    required DateTime after,
    bool preferCache = false,
  }) async {
    onCall?.call();
    calls += 1;
    if (calls == 1) return first;
    return afterFirst();
  }
}

final class _FakeNextPrayer implements NextPrayerProvider {
  _FakeNextPrayer(this._prayers);
  final List<NextPrayer> _prayers;

  @override
  Future<NextPrayer> next({
    required DateTime after,
    bool preferCache = false,
  }) async {
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
  Future<AdzanAudioData> load(String voiceId) async => AdzanAudioData(
        bytes: Uint8List.fromList(List<int>.filled(32, 1)),
        contentType: 'audio/mpeg',
        extension: 'mp3',
      );
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

final class _FakeModes implements PrayerDeliveryModeSource {
  _FakeModes(this.mode);
  PrayerDeliveryMode mode;
  String? lastPrayerName;

  @override
  Future<PrayerDeliveryMode> modeFor(String prayerName) async {
    lastPrayerName = prayerName;
    return mode;
  }
}

final class _FakeLocalPlayer implements LocalPrayerPlayer {
  final calls = <String>[];

  @override
  Future<void> playBeep() async => calls.add('beep');

  @override
  Future<void> playTakbir() async => calls.add('takbir');

  @override
  Future<void> playAdhan({
    required String voiceId,
    bool waitUntilDone = true,
  }) async =>
      calls.add('adhan:$voiceId');

  @override
  Future<void> stop() async => calls.add('stop');
}

final class _HangingLocalPlayer implements LocalPrayerPlayer {
  _HangingLocalPlayer({required this.started, required this.finished});

  final Completer<void> started;
  final Completer<void> finished;
  final calls = <String>[];
  final _play = Completer<void>();

  @override
  Future<void> playBeep() async => calls.add('beep');

  @override
  Future<void> playTakbir() async => calls.add('takbir');

  @override
  Future<void> playAdhan({
    required String voiceId,
    bool waitUntilDone = true,
  }) async {
    calls.add('adhan:$voiceId');
    if (!started.isCompleted) started.complete();
    await _play.future;
    if (!finished.isCompleted) finished.complete();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (!_play.isCompleted) _play.complete();
  }
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

  test('start 30s after T-120 still arms that prayer to fire immediately',
      () async {
    final maghribWake = maghrib.scheduledAt.add(PresenceSchedule.scanOffset);
    clock.advanceTo(maghribWake.add(const Duration(seconds: 30)));
    final coordinator = buildCoordinator();
    await coordinator.start();

    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.prayer, 'maghrib');
    expect(
      alarm.scheduled.single.epochMs,
      maghribWake.millisecondsSinceEpoch,
    );
  });

  test('start 82s after T-120 skips that prayer and arms the next', () async {
    final maghribWake = maghrib.scheduledAt.add(PresenceSchedule.scanOffset);
    clock.advanceTo(maghribWake.add(const Duration(seconds: 82)));
    final coordinator = buildCoordinator();
    await coordinator.start();

    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.prayer, 'isha');
    expect(
      alarm.scheduled.single.epochMs,
      isha.scheduledAt.add(PresenceSchedule.scanOffset).millisecondsSinceEpoch,
    );
  });

  test('start after azan+5 skips that prayer and arms the next', () async {
    clock.advanceTo(maghrib.scheduledAt.add(const Duration(minutes: 6)));
    final coordinator = buildCoordinator();
    await coordinator.start();

    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.prayer, 'isha');
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
    final next = await provider.next(after: t0, preferCache: false);
    expect(next.name, 'maghrib');
    final afterMaghrib =
        await provider.next(after: maghrib.scheduledAt, preferCache: false);
    expect(afterMaghrib.name, 'isha');
  });

  test('cast mode still calls orchestrator (away suppression stays there)',
      () async {
    final local = _FakeLocalPlayer();
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.cast),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
        deliveryDone.complete();
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.suppressedAway,
          role: null,
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;
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

    expect(deliveries, hasLength(1));
    expect(local.calls, isEmpty);
  });

  test('beep mode waits until azan then plays locally', () async {
    final local = _FakeLocalPlayer();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.beep),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
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
    final azanAt = DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true)
        .subtract(PresenceSchedule.scanOffset);
    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(deliveries, isEmpty);
    expect(local.calls, isEmpty);
    expect(alarm.stopForegroundCalls, 0);

    clock.advanceTo(azanAt);
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, isEmpty);
    expect(local.calls, ['beep']);
    expect(alarm.stopForegroundCalls, 1);
  });

  test('takbir mode waits until azan then plays locally', () async {
    final local = _FakeLocalPlayer();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.takbir),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
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
    final azanAt = DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true)
        .subtract(PresenceSchedule.scanOffset);
    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(local.calls, isEmpty);

    clock.advanceTo(azanAt);
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, isEmpty);
    expect(local.calls, ['takbir']);
    expect(alarm.stopForegroundCalls, 1);
  });

  test('adhanPhone mode waits until azan then plays local voice', () async {
    final local = _FakeLocalPlayer();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.adhanPhone),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
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
    final azanAt = DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true)
        .subtract(PresenceSchedule.scanOffset);
    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(deliveries, isEmpty);
    expect(local.calls, isEmpty);
    expect(alarm.stopForegroundCalls, 0);

    clock.advanceTo(azanAt);
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, isEmpty);
    expect(local.calls, ['adhan:makkah']);
    expect(alarm.callOrder, contains('showPhonePlaybackControls'));
    expect(alarm.stopForegroundCalls, 1);
  });

  test('adhanPhone Stop on the shade stops local playback', () async {
    final started = Completer<void>();
    final finished = Completer<void>();
    final local = _HangingLocalPlayer(started: started, finished: finished);
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.adhanPhone),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
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
    final azanAt = DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true)
        .subtract(PresenceSchedule.scanOffset);
    clock.advanceTo(azanAt);
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await started.future;
    alarm.emitStopLocalPlayback();
    await finished.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(local.calls, ['adhan:makkah', 'stop']);
    expect(alarm.stopForegroundCalls, 1);
  });

  test('scheduleDryRun 1 minute clamps wake after lock-screen delay', () async {
    final coordinator = buildCoordinator();
    await coordinator.start();

    final azanAt = await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn1Minute,
    );

    final expectedWake = t0.add(PrayerDeliveryCoordinator.dryRunMinWakeDelay);
    expect(azanAt, expectedWake.subtract(PresenceSchedule.scanOffset));
    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.epochMs, expectedWake.millisecondsSinceEpoch);
    expect(alarm.scheduled.single.prayer, 'maghrib-dryrun');
    expect(alarm.scheduled.single.voiceId, 'makkah');
    expect(
      coordinator.scheduledWakeEpochMs,
      expectedWake.millisecondsSinceEpoch,
    );
  });

  test('scheduleDryRun 5 minutes arms wake at now+5m + scanOffset', () async {
    final coordinator = buildCoordinator();
    await coordinator.start();

    final azanAt = await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn5Minutes,
    );

    expect(azanAt, t0.add(PrayerDeliveryCoordinator.dryRunIn5Minutes));
    final expectedWake = azanAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    expect(alarm.scheduled.single.epochMs, expectedWake);
    expect(alarm.scheduled.single.prayer, 'maghrib-dryrun');
    expect(coordinator.scheduledWakeEpochMs, expectedWake);
  });

  test('scheduleDryRun replaces a previous dry-run alarm', () async {
    final coordinator = buildCoordinator();
    await coordinator.start();

    await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn1Minute,
    );
    final secondAzan = await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn5Minutes,
    );

    expect(alarm.scheduled, hasLength(1));
    expect(
      alarm.scheduled.single.epochMs,
      secondAzan.add(PresenceSchedule.scanOffset).millisecondsSinceEpoch,
    );
    expect(alarm.scheduled.single.prayer, 'maghrib-dryrun');
  });

  test('dry-run fire uses canonical prayer mode then reschedules real next',
      () async {
    final modes = _FakeModes(PrayerDeliveryMode.cast);
    final deliveryDone = Completer<void>();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: modes,
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
    final azanAt = await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn1Minute,
    );
    final wakeMs = alarm.scheduled.single.epochMs;

    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib-dryrun',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    await deliveryDone.future;
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(modes.lastPrayerName, 'maghrib');
    expect(deliveries, hasLength(1));
    expect(deliveries.single.prayerName, 'maghrib-dryrun');
    expect(deliveries.single.scheduledAzan, azanAt);
    expect(deliveries.single.voiceId, 'makkah');
    expect(alarm.stopForegroundCalls, 1);
    expect(alarm.scheduled.single.prayer, 'maghrib');
    expect(alarm.scheduled.single.voiceId, 'makkah');
  });

  test('start keeps a future dry-run instead of replacing with next prayer',
      () async {
    final coordinator = buildCoordinator();
    await coordinator.start();
    final azanAt = await coordinator.scheduleDryRun(
      untilAzan: PrayerDeliveryCoordinator.dryRunIn1Minute,
    );
    final dryWake = azanAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    expect(alarm.scheduled.single.prayer, 'maghrib-dryrun');

    final restarted = buildCoordinator();
    await restarted.start();

    expect(alarm.scheduled, hasLength(1));
    expect(alarm.scheduled.single.prayer, 'maghrib-dryrun');
    expect(alarm.scheduled.single.epochMs, dryWake);
    expect(restarted.scheduledWakeEpochMs, dryWake);
  });

  test('reschedule failure arms reschedule-retry and skips delivery on that fire',
      () async {
    var nextCalls = 0;
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _CountingNextPrayer(
        first: maghrib,
        afterFirst: () => throw StateError('offline'),
        onCall: () => nextCalls += 1,
      ),
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
    );
    await coordinator.start();
    expect(nextCalls, 1);
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
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, hasLength(1));
    expect(alarm.scheduled, hasLength(1));
    expect(
      alarm.scheduled.single.prayer,
      PrayerDeliveryCoordinator.rescheduleRetryPrayer,
    );
    final retryWake = clock.now()
        .add(PrayerDeliveryCoordinator.rescheduleRetryDelay)
        .millisecondsSinceEpoch;
    expect(alarm.scheduled.single.epochMs, retryWake);
    expect(alarm.stopForegroundCalls, 1);

    alarm.stopForegroundCalls = 0;
    final retryEpoch = alarm.scheduled.single.epochMs;
    clock.advanceTo(
      DateTime.fromMillisecondsSinceEpoch(retryEpoch, isUtc: true),
    );
    alarm.emit(
      AlarmFiredEvent(
        prayer: PrayerDeliveryCoordinator.rescheduleRetryPrayer,
        scheduledEpochMs: retryEpoch,
        firedAtMs: retryEpoch,
        voiceId: PrayerDeliveryCoordinator.defaultVoiceId,
      ),
    );
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, hasLength(1));
    expect(
      alarm.scheduled.single.prayer,
      PrayerDeliveryCoordinator.rescheduleRetryPrayer,
    );
  });

  test(
    'start with pendingFire 50 minutes after azan does not Cast and arms next',
    () async {
      final db = DeliveryDatabase.memory();
      addTearDown(db.close);
      final dao = DeliveryLogDao(db);
      clock.advanceTo(maghrib.scheduledAt.add(const Duration(minutes: 50)));
      final coordinator = PrayerDeliveryCoordinator(
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
        logDao: dao,
      );
      await coordinator.start();
      expect(alarm.scheduled.single.prayer, 'isha');

      final wakeMs = maghrib.scheduledAt
          .add(PresenceSchedule.scanOffset)
          .millisecondsSinceEpoch;
      alarm.emit(
        AlarmFiredEvent(
          prayer: 'maghrib',
          scheduledEpochMs: wakeMs,
          firedAtMs: wakeMs + 50,
          voiceId: 'makkah',
        ),
      );
      for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(deliveries, isEmpty);
      expect(alarm.scheduled.single.prayer, 'isha');
      final rows = await dao.latest();
      expect(rows, hasLength(1));
      expect(rows.single.outcome, Outcome.failedAlarmMissed.code);
      expect(rows.single.detail, contains('after azan'));
    },
  );

  test('onFired within 3 minutes after azan still delivers', () async {
    final coordinator = buildCoordinator();
    await coordinator.start();
    final wakeMs = maghrib.scheduledAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    clock.advanceTo(maghrib.scheduledAt.add(const Duration(minutes: 3)));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs + 50,
        voiceId: 'makkah',
      ),
    );
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, hasLength(1));
    expect(deliveries.single.prayerName, 'maghrib');
    expect(alarm.scheduled.single.prayer, 'isha');
  });

  test('onFired with stale scheduledAt does not play', () async {
    final local = _FakeLocalPlayer();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm,
      nextPrayer: _FakeNextPrayer([maghrib, isha]),
      deviceConditions: _FakeConditions(),
      settings: _FakeSettings(),
      audioLoader: _FakeAudio(),
      deliveryModes: _FakeModes(PrayerDeliveryMode.adhanPhone),
      localPlayer: local,
      runDelivery: (request) async {
        deliveries.add(request);
        return const DeliveryAttemptResult(
          sessionId: 'sess',
          outcome: Outcome.played,
          role: 'SOLO',
        );
      },
      clock: clock,
    );
    await coordinator.start();
    final wakeMs = maghrib.scheduledAt
        .add(PresenceSchedule.scanOffset)
        .millisecondsSinceEpoch;
    clock.advanceTo(maghrib.scheduledAt.add(const Duration(minutes: 50)));
    alarm.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs,
        voiceId: 'makkah',
      ),
    );
    for (var i = 0; i < 50 && alarm.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(deliveries, isEmpty);
    expect(local.calls, isEmpty);
    expect(alarm.scheduled.single.prayer, 'isha');
  });

  test('DeliveryTiming grace is 5 minutes and next-wake cap is sooner', () {
    final azan = DateTime.utc(2026, 8, 15, 13, 9);
    expect(DeliveryTiming.graceAfterAzan, const Duration(minutes: 5));
    expect(
      DeliveryTiming.isTooLate(
        scheduledAzan: azan,
        now: azan.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    expect(
      DeliveryTiming.isTooLate(
        scheduledAzan: azan,
        now: azan.add(const Duration(minutes: 5, seconds: 1)),
      ),
      isTrue,
    );
    final nextWake = azan.add(const Duration(minutes: 2));
    expect(
      DeliveryTiming.deadline(
        scheduledAzan: azan,
        nextPrayerWake: nextWake,
      ),
      nextWake,
    );
  });

  test('canonicalPrayerName strips dry-run suffix only', () {
    expect(
      PrayerDeliveryCoordinator.canonicalPrayerName('isha-dryrun'),
      'isha',
    );
    expect(PrayerDeliveryCoordinator.canonicalPrayerName('isha'), 'isha');
    expect(PrayerDeliveryCoordinator.isDryRunPrayer('isha-dryrun'), isTrue);
    expect(PrayerDeliveryCoordinator.isDryRunPrayer('isha'), isFalse);
  });

  test('reschedule failure writes FAILED_RESCHEDULE to delivery log', () async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final dao = DeliveryLogDao(db);
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
      logDao: dao,
    );
    await coordinator.start();
    final wakeMs = alarm.scheduled.single.epochMs;

    // Make reschedule throw
    alarm.throwOnSchedule = true;
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

    // Should have logged FAILED_RESCHEDULE for the reschedule attempt
    final rows = await dao.latest();
    final failureRows = rows.where((r) => r.outcome == Outcome.failedReschedule.code);
    expect(failureRows, isNotEmpty);
    expect(failureRows.any((r) => r.prayer == 'maghrib'), isTrue);
    expect(failureRows.any((r) => r.detail != null && r.detail!.contains('scheduleNext failed')), isTrue);
  });

  test('reschedule retry failure writes FAILED_RESCHEDULE to delivery log', () async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final dao = DeliveryLogDao(db);
    final alarm2 = _FakeExactAlarm();
    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: alarm2,
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
      logDao: dao,
    );
    await coordinator.start();
    final wakeMs = alarm2.scheduled.single.epochMs;

    // Make reschedule throw to trigger retry path
    alarm2.throwOnSchedule = true;
    clock.advanceTo(DateTime.fromMillisecondsSinceEpoch(wakeMs, isUtc: true));
    alarm2.emit(
      AlarmFiredEvent(
        prayer: 'maghrib',
        scheduledEpochMs: wakeMs,
        firedAtMs: wakeMs + 50,
        voiceId: 'makkah',
      ),
    );
    for (var i = 0; i < 50 && alarm2.stopForegroundCalls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Should have logged both the reschedule failure and the retry failure
    final rows = await dao.latest();
    final failureRows = rows.where((r) => r.outcome == Outcome.failedReschedule.code);
    expect(failureRows, isNotEmpty);
    // One for the main reschedule (maghrib), one for the retry arm (reschedule-retry)
    expect(failureRows.any((r) => r.prayer == 'maghrib'), isTrue);
    expect(failureRows.any((r) => r.prayer == 'reschedule-retry'), isTrue);
    expect(failureRows.any((r) => r.detail != null && r.detail!.contains('Failed to arm retry')), isTrue);
  });
}
