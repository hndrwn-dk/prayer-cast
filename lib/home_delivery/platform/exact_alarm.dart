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

  /// Add a Stop action to the adzan FGS shade while phone adhan plays.
  Future<void> showPhonePlaybackControls({required String prayer});

  /// Play the bundled beep on [STREAM_ALARM] (audible with the screen off).
  Future<void> playLocalBeep();

  /// Play the bundled takbir tone on [STREAM_ALARM].
  Future<void> playLocalTakbir();

  /// Persist travel-update flag + last city coords for the native worker.
  Future<void> syncTravelLocation({
    required bool enabled,
    double? latitude,
    double? longitude,
  });

  /// Currently armed alarm, if any (from native prefs).
  Future<ScheduledAlarm?> readScheduled();

  /// Schedule a pre-prayer reminder notification (no FGS / Cast).
  Future<void> schedulePreAlert({
    required int epochMs,
    required String title,
    required String body,
    String sound = 'beep',
  });

  /// Cancel any armed pre-prayer reminder.
  Future<void> cancelPreAlert();

  /// Show a one-shot notification when Cast delivery fails.
  Future<void> showDeliveryFailureNotification({
    required String title,
    required String body,
  });

  /// Native may reuse this FlutterEngine for MainActivity only after ready.
  Future<void> markDeliveryReady();

  /// Clear persisted pending fire after Dart finished handling it.
  Future<void> acknowledgeAlarmFire();

  Stream<AlarmFiredEvent> get onFired;

  /// User tapped Stop on the phone-adhan notification.
  Stream<void> get onStopLocalPlayback;
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
  final StreamController<void> _stopLocalPlayback =
      StreamController<void>.broadcast();
  bool _nativeCallbacksBound = false;

  void _ensureNativeCallbacks() {
    if (_nativeCallbacksBound) return;
    _nativeCallbacksBound = true;
    _methods.setMethodCallHandler((call) async {
      if (call.method == 'stopLocalPlayback') {
        _stopLocalPlayback.add(null);
      }
    });
  }

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
  Future<void> showPhonePlaybackControls({required String prayer}) async {
    _ensureNativeCallbacks();
    try {
      await _methods.invokeMethod<void>('showPhonePlaybackControls', {
        'prayer': prayer,
      });
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'showPhonePlaybackControls: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'showPhonePlaybackControls failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> playLocalBeep() async {
    try {
      await _methods.invokeMethod<void>('playLocalBeep');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'playLocalBeep: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'playLocalBeep failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      throw ExactAlarmFailure('playLocalBeep failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> playLocalTakbir() async {
    try {
      await _methods.invokeMethod<void>('playLocalTakbir');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'playLocalTakbir: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'playLocalTakbir failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      throw ExactAlarmFailure('playLocalTakbir failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<void> syncTravelLocation({
    required bool enabled,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _methods.invokeMethod<void>('syncTravelLocation', {
        'enabled': enabled,
        'latitude': latitude,
        'longitude': longitude,
      });
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'syncTravelLocation: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'syncTravelLocation failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<void> get onStopLocalPlayback {
    _ensureNativeCallbacks();
    return _stopLocalPlayback.stream;
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
  Future<ScheduledAlarm?> readScheduled() async {
    try {
      final raw = await _methods.invokeMethod<Object?>('getScheduled');
      if (raw is! Map) return null;
      final map = <String, Object?>{
        for (final e in raw.entries) e.key.toString(): e.value,
      };
      final epoch = map['epochMs'];
      final prayer = map['prayer'];
      final voiceId = map['voiceId'];
      if (epoch is! num || prayer is! String) return null;
      return ScheduledAlarm(
        epochMs: epoch.toInt(),
        prayer: prayer,
        voiceId: voiceId is String ? voiceId : '',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e, st) {
      _logger.warn(
        'getScheduled failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> schedulePreAlert({
    required int epochMs,
    required String title,
    required String body,
    String sound = 'beep',
  }) async {
    try {
      await _methods.invokeMethod<void>('schedulePreAlert', {
        'epochMs': epochMs,
        'title': title,
        'body': body,
        'sound': sound,
      });
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'schedulePreAlert: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'schedulePreAlert failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> cancelPreAlert() async {
    try {
      await _methods.invokeMethod<void>('cancelPreAlert');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'cancelPreAlert: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'cancelPreAlert failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> showDeliveryFailureNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _methods.invokeMethod<void>('showDeliveryFailureNotification', {
        'title': title,
        'body': body,
      });
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'showDeliveryFailureNotification: plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'showDeliveryFailureNotification failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> markDeliveryReady() async {
    try {
      await _methods.invokeMethod<void>('markDeliveryReady');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'markDeliveryReady: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'markDeliveryReady failed',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> acknowledgeAlarmFire() async {
    try {
      await _methods.invokeMethod<void>('acknowledgeAlarmFire');
    } on MissingPluginException catch (e, st) {
      _logger.warn(
        'acknowledgeAlarmFire: exact_alarm plugin missing (no-op)',
        tag: 'ExactAlarm',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      _logger.warn(
        'acknowledgeAlarmFire failed',
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

/// Snapshot of the alarm currently persisted by the platform plugin.
final class ScheduledAlarm {
  const ScheduledAlarm({
    required this.epochMs,
    required this.prayer,
    required this.voiceId,
  });

  final int epochMs;
  final String prayer;
  final String voiceId;
}
