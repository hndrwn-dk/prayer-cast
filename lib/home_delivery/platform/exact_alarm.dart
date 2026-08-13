import 'dart:async';

import 'package:flutter/services.dart';

import '../common/logger.dart';
import '../logging/outcome.dart';

/// Fired when the platform alarm wakes the app (spec §5.5).
final class AlarmFiredEvent {
  const AlarmFiredEvent({
    required this.prayer,
    required this.scheduledEpochMs,
    required this.firedAtMs,
    this.voiceId,
  });

  final String prayer;
  final int scheduledEpochMs;
  final int firedAtMs;

  /// Bundled voice id persisted with the alarm. Null/empty only for legacy
  /// prefs written before voiceId was carried through.
  final String? voiceId;

  /// True when the fire was more than 60s after schedule (§6.2).
  bool get isMissed => firedAtMs - scheduledEpochMs > 60 * 1000;
}

/// Port for exact-alarm scheduling (injectable for unit tests).
abstract interface class ExactAlarmPlatform {
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  });

  Future<void> cancel();

  Future<bool> canScheduleExactAlarms();

  Future<void> requestExactAlarmPermission();

  Future<void> stopForegroundService();

  Stream<AlarmFiredEvent> get onFired;
}

/// MethodChannel bridge to Android `AlarmManager.setAlarmClock` (spec §5.5).
///
/// WHY: Exact wake-up that survives Doze. Requests `SCHEDULE_EXACT_ALARM` at
/// runtime; must NOT declare `USE_EXACT_ALARM` in the manifest (Play policy).
/// Schedules only the next alarm and reschedules on fire.
final class ExactAlarm implements ExactAlarmPlatform {
  ExactAlarm({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _methods = methodChannel ??
            const MethodChannel('prayer_cast/exact_alarm'),
        _events = eventChannel ??
            const EventChannel('prayer_cast/exact_alarm_events'),
        _logger = logger;

  final MethodChannel _methods;
  final EventChannel _events;
  final HomeDeliveryLogger _logger;
  Stream<AlarmFiredEvent>? _onFired;

  @override
  Future<void> scheduleNext({
    required int epochMs,
    required String prayer,
    required String voiceId,
  }) async {
    try {
      await _methods.invokeMethod<void>('scheduleNext', {
        'epochMs': epochMs,
        'prayer': prayer,
        'voiceId': voiceId,
      });
    } on MissingPluginException catch (e, st) {
      // iOS has no exact-alarm plugin — must not abort app start / reschedule.
      _logger.warn(
        'scheduleNext: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.error(
        'scheduleNext failed: ${e.code}',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      throw ExactAlarmFailure(
        e.code == 'no_permission'
            ? 'SCHEDULE_EXACT_ALARM not granted'
            : 'scheduleNext failed: ${e.message}',
        cause: e,
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _methods.invokeMethod<void>('cancel');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'cancel: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'cancel failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      throw ExactAlarmFailure('cancel failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      final value = await _methods.invokeMethod<bool>('canScheduleExactAlarms');
      return value ?? false;
    } on MissingPluginException catch (e, st) {
      // Android-only capability. Treat missing plugin (iOS) as granted so
      // coordinator.start() does not throw before runApp.
      _logger.warn(
        'canScheduleExactAlarms: exact_alarm plugin missing — treating as true',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      return true;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'canScheduleExactAlarms failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    try {
      await _methods.invokeMethod<void>('requestExactAlarmPermission');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'requestExactAlarmPermission: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'requestExactAlarmPermission failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      throw ExactAlarmFailure(
        'requestExactAlarmPermission failed: ${e.message}',
        cause: e,
      );
    }
  }

  @override
  Future<void> stopForegroundService() async {
    try {
      await _methods.invokeMethod<void>('stopForegroundService');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'stopForegroundService: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'stopForegroundService failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<AlarmFiredEvent> get onFired {
    return _onFired ??= _events.receiveBroadcastStream().map((raw) {
      if (raw is! Map) {
        throw ExactAlarmFailure('Malformed alarm event: $raw');
      }
      final map = <String, Object?>{
        for (final e in raw.entries) e.key.toString(): e.value,
      };
      final prayer = map['prayer'];
      final scheduled = map['scheduledEpochMs'];
      final fired = map['firedAtMs'];
      if (prayer is! String || scheduled is! num || fired is! num) {
        throw ExactAlarmFailure('Malformed alarm event fields: $map');
      }
      final voiceRaw = map['voiceId'];
      final voiceId = voiceRaw is String ? voiceRaw : null;
      return AlarmFiredEvent(
        prayer: prayer,
        scheduledEpochMs: scheduled.toInt(),
        firedAtMs: fired.toInt(),
        voiceId: voiceId,
      );
    });
  }
}

/// Typed exact-alarm failure (hard requirement #3).
final class ExactAlarmFailure implements Exception, OutcomeException {
  ExactAlarmFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  Outcome get outcome => Outcome.failedAlarmMissed;

  @override
  String toString() => 'ExactAlarmFailure: $message';
}
