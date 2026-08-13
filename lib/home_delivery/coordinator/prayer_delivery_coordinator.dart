import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/clock.dart';
import '../common/logger.dart';
import '../delivery/delivery_orchestrator.dart';
import '../platform/device_conditions.dart';
import '../platform/exact_alarm.dart';
import '../presence/presence_schedule.dart';
import 'adzan_audio_loader.dart';
import 'delivery_settings.dart';
import 'next_prayer_provider.dart';

/// Whether Android can schedule exact alarms (`SCHEDULE_EXACT_ALARM`).
///
/// Updated by [PrayerDeliveryCoordinator.start]. UI may watch this for a
/// minimal permission banner — no full settings screen in this pass.
final exactAlarmPermissionGrantedProvider = StateProvider<bool>((ref) => true);

/// Runs delivery end-to-end: schedule wake → onFired → orchestrator → reschedule.
///
/// This is the only module allowed to import `coordinator/`, `presence/`,
/// `coordination/`, `delivery/`, `platform/`, and `logging/` together — the
/// join point above [DeliveryOrchestrator].
///
/// ## Scheduling convention (load-bearing)
///
/// Wake epoch is azan epoch + [PresenceSchedule.scanOffset] (T−120 s).
/// Never hardcode `120000`.
///
/// ```
/// wakeEpochMs = azanEpoch.add(PresenceSchedule.scanOffset).millisecondsSinceEpoch
/// azanEpoch   = DateTime.fromMillisecondsSinceEpoch(event.scheduledEpochMs)
///                 .subtract(PresenceSchedule.scanOffset)
/// ```
///
/// Native [ExactAlarmPlugin] persists wake epoch in SharedPreferences and
/// buffers a cold-start fire via `pendingFire` until Dart listens — [start]
/// must subscribe to [ExactAlarmPlatform.onFired] before scheduling.
final class PrayerDeliveryCoordinator {
  PrayerDeliveryCoordinator({
    required ExactAlarmPlatform exactAlarm,
    required NextPrayerProvider nextPrayer,
    required DeviceConditionsProvider deviceConditions,
    required DeliverySettings settings,
    required AdzanAudioLoader audioLoader,
    required Future<DeliveryAttemptResult> Function(DeliveryRequest request)
        runDelivery,
    required Clock clock,
    void Function(bool granted)? onPermissionChanged,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _exactAlarm = exactAlarm,
        _nextPrayer = nextPrayer,
        _deviceConditions = deviceConditions,
        _settings = settings,
        _audioLoader = audioLoader,
        _runDelivery = runDelivery,
        _clock = clock,
        _onPermissionChanged = onPermissionChanged,
        _logger = logger;

  /// Fallback when a fired event has no voiceId (legacy prefs / corruption).
  static const String defaultVoiceId = 'makkah';

  final ExactAlarmPlatform _exactAlarm;
  final NextPrayerProvider _nextPrayer;
  final DeviceConditionsProvider _deviceConditions;
  final DeliverySettings _settings;
  final AdzanAudioLoader _audioLoader;
  final Future<DeliveryAttemptResult> Function(DeliveryRequest request)
      _runDelivery;
  final Clock _clock;
  final void Function(bool granted)? _onPermissionChanged;
  final HomeDeliveryLogger _logger;

  StreamSubscription<AlarmFiredEvent>? _fireSub;
  int? _lastHandledWakeEpochMs;
  int? _scheduledWakeEpochMs;
  bool _started = false;
  bool _handling = false;

  /// Last wake epoch successfully armed (for tests / diagnostics).
  int? get scheduledWakeEpochMs => _scheduledWakeEpochMs;

  /// Last wake epoch that completed a delivery attempt (for tests).
  int? get lastHandledWakeEpochMs => _lastHandledWakeEpochMs;

  /// Subscribe to fires, check permission, schedule the next wake.
  ///
  /// Call once from `main` after the delivery DB is open and before the first
  /// frame so a buffered native `pendingFire` is not missed.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Listen FIRST — native may already hold pendingFire from a cold start.
    _fireSub = _exactAlarm.onFired.listen(
      (event) {
        unawaited(_onFired(event));
      },
      onError: (Object e, StackTrace st) {
        _logger.error(
          'ExactAlarm.onFired stream error',
          tag: 'PrayerDeliveryCoordinator',
          error: e,
          stackTrace: st,
        );
      },
    );

    await _tryScheduleIfPermitted();
  }

  /// Re-check `SCHEDULE_EXACT_ALARM` and arm a wake if none is scheduled yet.
  ///
  /// Call after the user returns from the system exact-alarm settings screen
  /// (and on app resume). Without this, a fresh Android 12+ install that
  /// denied permission at [start] never arms an alarm until process restart —
  /// every prayer is missed.
  Future<void> retryScheduleAfterPermissionGranted() async {
    if (!_started) return;
    if (_scheduledWakeEpochMs != null) return;
    if (_handling) return;
    await _tryScheduleIfPermitted();
  }

  Future<void> _tryScheduleIfPermitted() async {
    final canSchedule = await _exactAlarm.canScheduleExactAlarms();
    _onPermissionChanged?.call(canSchedule);
    if (!canSchedule) {
      _logger.warn(
        'SCHEDULE_EXACT_ALARM not granted — not scheduling (UI may prompt)',
        tag: 'PrayerDeliveryCoordinator',
      );
      return;
    }

    await _scheduleNextAfter(_clock.now());
  }

  Future<void> dispose() async {
    await _fireSub?.cancel();
    _fireSub = null;
    _started = false;
  }

  Future<void> _onFired(AlarmFiredEvent event) async {
    // Idempotency: native buffering + stream replay can double-deliver.
    if (_lastHandledWakeEpochMs == event.scheduledEpochMs) {
      _logger.info(
        'Ignoring duplicate onFired for wake ${event.scheduledEpochMs}',
        tag: 'PrayerDeliveryCoordinator',
      );
      return;
    }
    if (_handling) {
      _logger.warn(
        'Delivery already in progress — ignoring concurrent onFired',
        tag: 'PrayerDeliveryCoordinator',
      );
      return;
    }
    _handling = true;
    _lastHandledWakeEpochMs = event.scheduledEpochMs;

    // Epoch ms are absolute instants; reconstruct as UTC so equality with
    // calc-engine UTC schedules (and unit tests) is stable.
    final wakeAt = DateTime.fromMillisecondsSinceEpoch(
      event.scheduledEpochMs,
      isUtc: true,
    );
    final azanEpoch = wakeAt.subtract(PresenceSchedule.scanOffset);
    final firedAt = DateTime.fromMillisecondsSinceEpoch(
      event.firedAtMs,
      isUtc: true,
    );

    try {
      // 1) Run delivery — log failures, do not let them skip reschedule.
      try {
        final castId = await _settings.homeCastDeviceId();
        final volume = await _settings.playbackVolume();
        final voiceId = _resolveVoiceId(event.voiceId);
        final audio = await _audioLoader.load(voiceId);
        final conditions = await _deviceConditions.current();

        final request = DeliveryRequest(
          prayerName: event.prayer,
          scheduledAzan: azanEpoch,
          voiceId: voiceId,
          audioBytes: audio,
          homeCastDeviceId: castId ?? '',
          playbackVolume: volume,
          deviceConditions: conditions,
          firedAt: firedAt,
        );
        await _runDelivery(request);
      } catch (e, st) {
        _logger.error(
          'Delivery attempt failed after alarm fire',
          tag: 'PrayerDeliveryCoordinator',
          error: e,
          stackTrace: st,
        );
      }

      // 2) Reschedule next wake while FGS / wake / Wi-Fi locks are still held.
      try {
        final canSchedule = await _exactAlarm.canScheduleExactAlarms();
        _onPermissionChanged?.call(canSchedule);
        if (canSchedule) {
          await _scheduleNextAfter(azanEpoch);
        }
      } catch (e, st) {
        _logger.error(
          'Reschedule after fire failed',
          tag: 'PrayerDeliveryCoordinator',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      // 3) Always release FGS locks — even if delivery or reschedule threw.
      _handling = false;
      await _exactAlarm.stopForegroundService();
    }
  }

  String _resolveVoiceId(String? voiceId) {
    if (voiceId != null && voiceId.isNotEmpty) return voiceId;
    _logger.warn(
      'AlarmFiredEvent missing voiceId — falling back to $defaultVoiceId '
      '(legacy prefs or corrupted payload)',
      tag: 'PrayerDeliveryCoordinator',
    );
    return defaultVoiceId;
  }

  Future<void> _scheduleNextAfter(DateTime after) async {
    var cursor = after;
    for (var i = 0; i < 16; i++) {
      final prayer = await _nextPrayer.next(after: cursor);
      final wakeEpochMs = prayer.scheduledAt
          .add(PresenceSchedule.scanOffset)
          .millisecondsSinceEpoch;

      // Do not arm a wake that is already in the past.
      if (wakeEpochMs <= _clock.now().millisecondsSinceEpoch) {
        _logger.warn(
          'Next wake $wakeEpochMs already past — advancing further',
          tag: 'PrayerDeliveryCoordinator',
        );
        cursor = prayer.scheduledAt;
        continue;
      }

      await _exactAlarm.scheduleNext(
        epochMs: wakeEpochMs,
        prayer: prayer.name,
        voiceId: prayer.voiceId,
      );
      _scheduledWakeEpochMs = wakeEpochMs;
      _logger.info(
        'Scheduled wake at $wakeEpochMs for ${prayer.name} '
        '(azan ${prayer.scheduledAt.millisecondsSinceEpoch}, '
        'voice ${prayer.voiceId})',
        tag: 'PrayerDeliveryCoordinator',
      );
      return;
    }
    _logger.error(
      'Unable to find a future wake after $after',
      tag: 'PrayerDeliveryCoordinator',
    );
  }
}
