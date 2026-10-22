import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/presence/presence_state.dart';

/// What happened when a scheduled adhkar alarm fired.
typedef AdhkarAlarmLog =
    Future<void> Function({
      required Outcome outcome,
      required AdhkarType type,
      required int scheduledAtMs,
      String? detail,
    });

/// Plays scheduled adhkar only at home, on a connected speaker.
///
/// A busy Cast session (adzan or anything else still playing) is retried
/// once. The next day's alarm is armed after every terminal result.
///
/// After a successful start, [hold] keeps this fire open until the
/// recitation ends, so the caller does not drop the foreground service
/// (and the phone's media server) while the speaker is still streaming.
final class AdhkarAlarmHandler {
  AdhkarAlarmHandler({
    required Future<AdhkarDeliveryResult> Function(AdhkarType type) play,
    required Future<PresenceState> Function() readPresence,
    required Future<bool> Function() speakerConnected,
    required Future<bool> Function() castBusy,
    required AdhkarAlarmLog log,
    required Future<void> Function() sync,
    Future<void> Function(Duration delay)? wait,
    Future<void> Function(AdhkarType type)? hold,
    this.retryAfter = const Duration(minutes: 2),
  }) : _play = play,
       _hold = hold,
       _readPresence = readPresence,
       _speakerConnected = speakerConnected,
       _castBusy = castBusy,
       _log = log,
       _sync = sync,
       _wait = wait ?? Future<void>.delayed;

  final Future<AdhkarDeliveryResult> Function(AdhkarType type) _play;
  final Future<PresenceState> Function() _readPresence;
  final Future<bool> Function() _speakerConnected;
  final Future<bool> Function() _castBusy;
  final AdhkarAlarmLog _log;
  final Future<void> Function() _sync;
  final Future<void> Function(Duration delay) _wait;
  final Future<void> Function(AdhkarType type)? _hold;
  final Duration retryAfter;

  final Set<String> _handled = {};

  Future<void> onFired(
    AdhkarType type, {
    required int scheduledEpochMs,
    bool retried = false,
  }) async {
    if (!retried) {
      final key = '${type.name}:$scheduledEpochMs';
      if (!_handled.add(key)) return;
    }

    final presence = await _presence();
    if (presence != PresenceState.home) {
      await _finish(
        type,
        scheduledEpochMs,
        Outcome.adhkarSkippedAway,
        detail: presence.name,
      );
      return;
    }

    final connected = await _speaker();
    if (!connected) {
      await _finish(
        type,
        scheduledEpochMs,
        Outcome.adhkarSkippedOffline,
        detail: 'speaker offline',
      );
      return;
    }

    if (await _busy()) {
      if (!retried) {
        await _wait(retryAfter);
        await onFired(type, scheduledEpochMs: scheduledEpochMs, retried: true);
        return;
      }
      await _finish(
        type,
        scheduledEpochMs,
        Outcome.adhkarFailed,
        detail: 'cast busy',
      );
      return;
    }

    final result = await _play(type);
    final outcome = switch (result) {
      AdhkarDeliveryResult.success => Outcome.adhkarPlayed,
      AdhkarDeliveryResult.speakerOffline => Outcome.adhkarSkippedOffline,
      AdhkarDeliveryResult.audioMissing ||
      AdhkarDeliveryResult.castFailed => Outcome.adhkarFailed,
    };
    await _finish(type, scheduledEpochMs, outcome, detail: result.name);
    if (result == AdhkarDeliveryResult.success) {
      final hold = _hold;
      if (hold == null) return;
      try {
        await hold(type);
      } catch (_) {}
    }
  }

  Future<PresenceState> _presence() async {
    try {
      return await _readPresence();
    } catch (_) {
      return PresenceState.unknown;
    }
  }

  Future<bool> _speaker() async {
    try {
      return await _speakerConnected();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _busy() async {
    try {
      return await _castBusy();
    } catch (_) {
      return false;
    }
  }

  Future<void> _finish(
    AdhkarType type,
    int scheduledAtMs,
    Outcome outcome, {
    String? detail,
  }) async {
    try {
      await _log(
        outcome: outcome,
        type: type,
        scheduledAtMs: scheduledAtMs,
        detail: detail,
      );
    } catch (_) {}
    try {
      await _sync();
    } catch (_) {}
  }
}
