import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayer_times/prayer_prefs.dart';
import '../../prayer_times/travel_schedule_refresher.dart';
import '../common/clock.dart';
import '../common/logger.dart';
import '../common/scheduler.dart';
import '../delivery/delivery_orchestrator.dart';
import '../delivery/delivery_timing.dart';
import '../logging/delivery_log_dao.dart';
import '../logging/outcome.dart';
import '../platform/device_conditions.dart';
import '../platform/exact_alarm.dart';
import '../presence/presence_schedule.dart';
import 'adzan_audio_loader.dart';
import 'delivery_settings.dart';
import 'local_prayer_player.dart';
import 'next_prayer_provider.dart';
import 'pre_prayer_alert_scheduler.dart';
import 'prayer_delivery_mode_source.dart';

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
    PrayerDeliveryModeSource? deliveryModes,
    LocalPrayerPlayer? localPlayer,
    DeliveryLogDao? logDao,
    PrePrayerAlertScheduler? prePrayerAlerts,
    TravelScheduleRefresher? travelRefresher,
    Future<String?> Function()? readLocaleCode,
    void Function(bool granted)? onPermissionChanged,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _exactAlarm = exactAlarm,
        _nextPrayer = nextPrayer,
        _deviceConditions = deviceConditions,
        _settings = settings,
        _audioLoader = audioLoader,
        _runDelivery = runDelivery,
        _clock = clock,
        _deliveryModes = deliveryModes ?? const AlwaysCastDeliveryModeSource(),
        _localPlayer = localPlayer ?? const SilentLocalPrayerPlayer(),
        _logDao = logDao,
        _prePrayerAlerts = prePrayerAlerts,
        _travelRefresher = travelRefresher,
        _readLocaleCode = readLocaleCode ?? (() async => null),
        _onPermissionChanged = onPermissionChanged,
        _logger = logger;

  /// Fallback when a fired event has no voiceId (legacy prefs / corruption).
  static const String defaultVoiceId = 'standard_adhan';

  /// Alarm / log marker so a dry-run is visible without colliding with
  /// production queries for canonical names (`isha`, `maghrib`, …).
  static const String dryRunPrayerSuffix = '-dryrun';

  /// Azan-in-1-minute dry-run. Wake is still T−120 when that fits.
  static const Duration dryRunIn1Minute = Duration(minutes: 1);

  /// Azan-in-5-minutes dry-run. Wake is still T−120.
  static const Duration dryRunIn5Minutes = Duration(minutes: 5);

  /// Floor for a clamped dry-run wake. A 1-minute slot cannot fit T−120;
  /// delaying past 1s lets the user leave settings / lock so the FGS
  /// shade can heads-up before azan.
  static const Duration dryRunMinWakeDelay = Duration(seconds: 25);

  /// Strip [dryRunPrayerSuffix] so mode / voice lookup uses the real slot.
  static String canonicalPrayerName(String prayer) {
    if (prayer.endsWith(dryRunPrayerSuffix)) {
      return prayer.substring(0, prayer.length - dryRunPrayerSuffix.length);
    }
    return prayer;
  }

  static bool isDryRunPrayer(String prayer) =>
      prayer.endsWith(dryRunPrayerSuffix);

  /// Wake-only retry when the next prayer cannot be resolved (offline cache miss).
  static const String rescheduleRetryPrayer = 'reschedule-retry';

  static const Duration rescheduleRetryDelay = Duration(minutes: 15);

  static bool isRescheduleRetry(String prayer) =>
      prayer == rescheduleRetryPrayer;

  final ExactAlarmPlatform _exactAlarm;
  final NextPrayerProvider _nextPrayer;
  final DeviceConditionsProvider _deviceConditions;
  final DeliverySettings _settings;
  final AdzanAudioLoader _audioLoader;
  final Future<DeliveryAttemptResult> Function(DeliveryRequest request)
      _runDelivery;
  final Clock _clock;
  final PrayerDeliveryModeSource _deliveryModes;
  final LocalPrayerPlayer _localPlayer;
  final DeliveryLogDao? _logDao;
  final PrePrayerAlertScheduler? _prePrayerAlerts;
  final TravelScheduleRefresher? _travelRefresher;
  final Future<String?> Function() _readLocaleCode;
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

    final existing = await _exactAlarm.readScheduled();
    if (existing != null &&
        isDryRunPrayer(existing.prayer) &&
        existing.epochMs > _clock.now().millisecondsSinceEpoch) {
      _scheduledWakeEpochMs = existing.epochMs;
      _logger.info(
        'Keeping armed dry-run wake at ${existing.epochMs} '
        'for ${existing.prayer}',
        tag: 'PrayerDeliveryCoordinator',
      );
      return;
    }

    await _travelRefresher?.refreshIfMoved();
    await _scheduleNextAfter(_clock.now());
  }

  Future<void> dispose() async {
    await _fireSub?.cancel();
    _fireSub = null;
    _started = false;
  }

  /// Arm the same AlarmClock → FGS (with shade notification) → [onFired]
  /// path as a real prayer, with azan at now + [untilAzan] (wake at T−120
  /// when that is still in the future). A 1-minute dry-run cannot fit
  /// T−120, so wake is clamped to now + [dryRunMinWakeDelay]; [onFired]
  /// still reconstructs azan as wake + 120s. Replaces any previously
  /// scheduled wake, including an earlier dry-run.
  ///
  /// Uses the next upcoming prayer's name + voice so Cast/beep/phone mode
  /// matches that slot. Returns the azan instant for the inline confirmation.
  Future<DateTime> scheduleDryRun({required Duration untilAzan}) async {
    if (!_started) {
      throw StateError('Coordinator not started');
    }
    if (_handling) {
      throw StateError('Delivery already in progress');
    }

    final canSchedule = await _exactAlarm.canScheduleExactAlarms();
    _onPermissionChanged?.call(canSchedule);
    if (!canSchedule) {
      throw ExactAlarmFailure('SCHEDULE_EXACT_ALARM not granted');
    }

    final now = _clock.now();
    if (untilAzan <= Duration.zero) {
      throw ArgumentError.value(
        untilAzan,
        'untilAzan',
        'must be after now',
      );
    }
    final requestedAzan = now.add(untilAzan);
    final computedWake = requestedAzan.add(PresenceSchedule.scanOffset);
    final minWake = now.add(dryRunMinWakeDelay);
    final wakeAt = computedWake.isAfter(minWake) ? computedWake : minWake;
    final wakeEpochMs = wakeAt.millisecondsSinceEpoch;
    final azanEpoch = wakeAt.subtract(PresenceSchedule.scanOffset);

    var name = 'isha';
    var voiceId = defaultVoiceId;
    try {
      final upcoming = await _nextPrayer.next(after: now, preferCache: false);
      final canonical = canonicalPrayerName(upcoming.name);
      if (canonical.isNotEmpty) name = canonical;
      if (upcoming.voiceId.isNotEmpty) voiceId = upcoming.voiceId;
    } catch (e, st) {
      _logger.warn(
        'Dry-run falling back to $name / $voiceId',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
    }

    final prayer = '$name$dryRunPrayerSuffix';
    await _exactAlarm.scheduleNext(
      epochMs: wakeEpochMs,
      prayer: prayer,
      voiceId: voiceId,
    );
    _scheduledWakeEpochMs = wakeEpochMs;
    _logger.info(
      'Scheduled dry-run wake at $wakeEpochMs for $prayer '
      '(azan ${azanEpoch.millisecondsSinceEpoch}, voice $voiceId)',
      tag: 'PrayerDeliveryCoordinator',
    );
    return azanEpoch;
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
      if (!isRescheduleRetry(event.prayer)) {
        try {
          await _deliver(event, azanEpoch: azanEpoch, firedAt: firedAt);
        } catch (e, st) {
          _logger.error(
            'Delivery attempt failed after alarm fire',
            tag: 'PrayerDeliveryCoordinator',
            error: e,
            stackTrace: st,
          );
        }
      }

      // 2) Reschedule next wake while FGS / wake / Wi-Fi locks are still held.
      try {
        final canSchedule = await _exactAlarm.canScheduleExactAlarms();
        _onPermissionChanged?.call(canSchedule);
        if (canSchedule) {
          final after = isRescheduleRetry(event.prayer)
              ? _clock.now()
              : azanEpoch;
          await _scheduleNextAfter(after);
        }
      } catch (e, st) {
        _logger.error(
          'Reschedule after fire failed',
          tag: 'PrayerDeliveryCoordinator',
          error: e,
          stackTrace: st,
        );
        await _logRescheduleFailure(
          event: event,
          azanEpoch: azanEpoch,
          exception: e,
        );
        await _armRescheduleRetry();
      }
    } finally {
      // 3) Always release FGS locks — even if delivery or reschedule threw.
      _handling = false;
      await _exactAlarm.stopForegroundService();
    }
  }

  /// Branch on per-prayer mode before the Cast orchestrator.
  ///
  /// Beep / phone Adhan skip presence and election. Cast keeps the existing
  /// away → SUPPRESSED_AWAY path with no phone fallback.
  Future<void> _deliver(
    AlarmFiredEvent event, {
    required DateTime azanEpoch,
    required DateTime firedAt,
  }) async {
    final now = _clock.now();
    if (DeliveryTiming.isTooLate(scheduledAzan: azanEpoch, now: now)) {
      final late = now.difference(azanEpoch);
      _logger.warn(
        'Skipping stale ${event.prayer}: dart now is ${late.inSeconds}s after '
        'azan (grace ${DeliveryTiming.graceAfterAzan.inMinutes}m)',
        tag: 'PrayerDeliveryCoordinator',
      );
      await _logStaleMiss(
        event: event,
        azanEpoch: azanEpoch,
        now: now,
        late: late,
      );
      return;
    }

    final prayerName = canonicalPrayerName(event.prayer);
    final mode = await _deliveryModes.modeFor(prayerName);
    if (mode == PrayerDeliveryMode.beep) {
      _logger.info(
        'Local beep for ${event.prayer} (skip Cast)',
        tag: 'PrayerDeliveryCoordinator',
      );
      await _waitUntilAzan(azanEpoch);
      if (DeliveryTiming.isTooLate(scheduledAzan: azanEpoch, now: _clock.now())) {
        return;
      }
      await _localPlayer.playBeep();
      return;
    }
    if (mode == PrayerDeliveryMode.takbir) {
      _logger.info(
        'Local takbir for ${event.prayer} (skip Cast)',
        tag: 'PrayerDeliveryCoordinator',
      );
      await _waitUntilAzan(azanEpoch);
      if (DeliveryTiming.isTooLate(scheduledAzan: azanEpoch, now: _clock.now())) {
        return;
      }
      await _localPlayer.playTakbir();
      return;
    }
    if (mode == PrayerDeliveryMode.adhanPhone) {
      final voiceId = _resolveVoiceId(event.voiceId);
      _logger.info(
        'Local adhan for ${event.prayer} voice=$voiceId (skip Cast)',
        tag: 'PrayerDeliveryCoordinator',
      );
      await _waitUntilAzan(azanEpoch);
      if (DeliveryTiming.isTooLate(scheduledAzan: azanEpoch, now: _clock.now())) {
        return;
      }
      await _exactAlarm.showPhonePlaybackControls(prayer: event.prayer);
      final stopSub = _exactAlarm.onStopLocalPlayback.listen((_) {
        unawaited(_localPlayer.stop());
      });
      try {
        await _localPlayer.playAdhan(voiceId: voiceId);
      } finally {
        await stopSub.cancel();
      }
      return;
    }

    final castId = await _settings.homeCastDeviceId();
    final volume = await _settings.playbackVolume();
    final voiceId = _resolveVoiceId(event.voiceId);
    final audio = await _audioLoader.load(voiceId);
    final conditions = await _deviceConditions.current();

    final request = DeliveryRequest(
      prayerName: event.prayer,
      scheduledAzan: azanEpoch,
      voiceId: voiceId,
      audioBytes: audio.bytes,
      contentType: audio.contentType,
      mediaExtension: audio.extension,
      homeCastDeviceId: castId ?? '',
      playbackVolume: volume,
      deviceConditions: conditions,
      firedAt: firedAt,
    );
    final result = await _runDelivery(request);
    await _maybeNotifyCastFailure(
      result: result,
      prayerName: event.prayer,
    );
  }

  static const _castFailureOutcomes = {
    Outcome.failedNoTarget,
    Outcome.failedNoRoute,
    Outcome.failedCastConnect,
    Outcome.failedLoadMedia,
  };

  Future<void> _maybeNotifyCastFailure({
    required DeliveryAttemptResult result,
    required String prayerName,
  }) async {
    if (!_castFailureOutcomes.contains(result.outcome)) return;
    final localeCode = await _readLocaleCode();
    final isId = localeCode != 'en';
    final copy = CastFailureNotificationCopy.forOutcome(
      outcomeCode: result.outcome.code,
      prayerName: prayerName,
      isId: isId,
    );
    await _exactAlarm.showDeliveryFailureNotification(
      title: copy.title,
      body: copy.body,
    );
  }

  Future<void> _logStaleMiss({
    required AlarmFiredEvent event,
    required DateTime azanEpoch,
    required DateTime now,
    required Duration late,
  }) async {
    final dao = _logDao;
    if (dao == null) return;
    try {
      await dao.insertAttempt(
        sessionId: 'stale-${event.scheduledEpochMs}',
        prayer: event.prayer,
        scheduledAtMs: azanEpoch.millisecondsSinceEpoch,
        firedAtMs: now.millisecondsSinceEpoch,
        outcome: Outcome.failedAlarmMissed,
        detail: 'dart started ${late.inSeconds}s after azan '
            '(grace ${DeliveryTiming.graceAfterAzan.inMinutes}m)',
      );
    } catch (e, st) {
      _logger.warn(
        'Failed to log stale miss for ${event.prayer}',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Beep / phone adhan must wait until T, same as Cast loadMedia.
  /// Wake is T−120; playing at wake made phone adhan two minutes early.
  Future<void> _waitUntilAzan(DateTime azanEpoch) async {
    final clock = _clock;
    if (clock is Scheduler) {
      await clock.waitUntil(azanEpoch);
      return;
    }
    while (_clock.now().isBefore(azanEpoch)) {
      final remaining = azanEpoch.difference(_clock.now());
      if (remaining <= Duration.zero) return;
      final slice = remaining > const Duration(milliseconds: 50)
          ? const Duration(milliseconds: 50)
          : remaining;
      await Future<void>.delayed(slice);
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

  /// Re-sync the pre-prayer reminder after prefs change (e.g. minutes toggle).
  Future<void> refreshPrePrayerAlert() async {
    if (!_started) return;
    final scheduler = _prePrayerAlerts;
    if (scheduler == null) return;
    final scheduled = await _exactAlarm.readScheduled();
    if (scheduled == null) {
      await scheduler.cancel();
      return;
    }
    if (PrayerDeliveryCoordinator.isDryRunPrayer(scheduled.prayer) ||
        PrayerDeliveryCoordinator.isRescheduleRetry(scheduled.prayer)) {
      await scheduler.cancel();
      return;
    }
    final wakeAt = DateTime.fromMillisecondsSinceEpoch(
      scheduled.epochMs,
      isUtc: true,
    );
    final azanAt = wakeAt.subtract(PresenceSchedule.scanOffset);
    final prayer = NextPrayer(
      name: scheduled.prayer,
      scheduledAt: azanAt,
      voiceId: scheduled.voiceId,
    );
    await scheduler.syncForPrayer(prayer, _clock.now());
  }

  Future<void> syncTravelLocation() async {
    await _travelRefresher?.syncFromStore();
  }

  Future<void> _scheduleNextAfter(DateTime after) async {
    var cursor = after;
    for (var i = 0; i < 16; i++) {
      final prayer = await _nextPrayer.next(after: cursor, preferCache: true);
      final wakeEpochMs = prayer.scheduledAt
          .add(PresenceSchedule.scanOffset)
          .millisecondsSinceEpoch;
      final now = _clock.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Wake already past: still arm it when AlarmManager will fire
      // immediately and delivery is still eligible (package replace /
      // late open inside T−120..T, within the 60s OEM window).
      // Otherwise skip — opening after Isha+5 must not blast the speaker.
      if (wakeEpochMs <= nowMs) {
        final wakeLate = Duration(milliseconds: nowMs - wakeEpochMs);
        final stillEligible = !DeliveryTiming.isTooLate(
              scheduledAzan: prayer.scheduledAt,
              now: now,
            ) &&
            wakeLate <= DeliveryOrchestrator.alarmMissedThreshold;
        if (stillEligible) {
          _logger.warn(
            'Next wake $wakeEpochMs already past by ${wakeLate.inSeconds}s '
            'but still eligible — arming to fire immediately',
            tag: 'PrayerDeliveryCoordinator',
          );
          await _exactAlarm.scheduleNext(
            epochMs: wakeEpochMs,
            prayer: prayer.name,
            voiceId: prayer.voiceId,
          );
          _scheduledWakeEpochMs = wakeEpochMs;
          await _prePrayerAlerts?.syncForPrayer(prayer, now);
          return;
        }
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
      await _prePrayerAlerts?.syncForPrayer(prayer, now);
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
    throw StateError('Unable to find a future wake after $after');
  }

  /// Keep a wake path if Aladhan/cache cannot resolve the next prayer.
  Future<void> _armRescheduleRetry() async {
    try {
      final canSchedule = await _exactAlarm.canScheduleExactAlarms();
      if (!canSchedule) return;
      final wake = _clock.now().add(rescheduleRetryDelay);
      final epochMs = wake.millisecondsSinceEpoch;
      await _exactAlarm.scheduleNext(
        epochMs: epochMs,
        prayer: rescheduleRetryPrayer,
        voiceId: defaultVoiceId,
      );
      _scheduledWakeEpochMs = epochMs;
      _logger.warn(
        'Armed $rescheduleRetryPrayer at $epochMs',
        tag: 'PrayerDeliveryCoordinator',
      );
      await _logRescheduleRetryArmed(epochMs);
    } catch (e, st) {
      _logger.error(
        'Failed to arm reschedule retry',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
      await _logRescheduleRetryFailure(exception: e);
    }
  }

  /// Log a post-delivery reschedule failure to the persistent delivery log.
  Future<void> _logRescheduleFailure({
    required AlarmFiredEvent event,
    required DateTime azanEpoch,
    required Object exception,
  }) async {
    final dao = _logDao;
    if (dao == null) return;
    try {
      await dao.insertAttempt(
        sessionId: 'reschedule-${event.scheduledEpochMs}',
        prayer: event.prayer,
        scheduledAtMs: azanEpoch.millisecondsSinceEpoch,
        firedAtMs: _clock.now().millisecondsSinceEpoch,
        outcome: Outcome.failedReschedule,
        detail: exception.toString(),
      );
    } catch (e, st) {
      _logger.warn(
        'Failed to log reschedule failure for ${event.prayer}',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Log that a reschedule retry was armed (informational marker).
  Future<void> _logRescheduleRetryArmed(int epochMs) async {
    final dao = _logDao;
    if (dao == null) return;
    try {
      await dao.insertAttempt(
        sessionId: 'retry-$epochMs',
        prayer: rescheduleRetryPrayer,
        scheduledAtMs: epochMs,
        firedAtMs: _clock.now().millisecondsSinceEpoch,
        outcome: Outcome.rescheduleRetryArmed,
        detail: '15-second retry wake armed',
      );
    } catch (e, st) {
      _logger.warn(
        'Failed to log reschedule retry armed',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Log failure to arm the reschedule retry itself.
  Future<void> _logRescheduleRetryFailure({required Object exception}) async {
    final dao = _logDao;
    if (dao == null) return;
    try {
      await dao.insertAttempt(
        sessionId: 'retry-fail-${_clock.now().millisecondsSinceEpoch}',
        prayer: rescheduleRetryPrayer,
        scheduledAtMs: _clock.now().millisecondsSinceEpoch,
        firedAtMs: _clock.now().millisecondsSinceEpoch,
        outcome: Outcome.failedReschedule,
        detail: 'Failed to arm retry: ${exception.toString()}',
      );
    } catch (e, st) {
      _logger.warn(
        'Failed to log reschedule retry failure',
        tag: 'PrayerDeliveryCoordinator',
        error: e,
        stackTrace: st,
      );
    }
  }
}
