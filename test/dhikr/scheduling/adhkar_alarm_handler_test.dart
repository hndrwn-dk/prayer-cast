import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_alarm_handler.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/presence/presence_state.dart';

void main() {
  late List<AdhkarType> played;
  late List<Outcome> outcomes;
  late List<String?> details;
  late int syncs;
  late List<Duration> waits;
  late PresenceState presence;
  late bool speaker;
  late bool busy;

  setUp(() {
    played = [];
    outcomes = [];
    details = [];
    syncs = 0;
    waits = [];
    presence = PresenceState.home;
    speaker = true;
    busy = false;
  });

  AdhkarAlarmHandler build() {
    return AdhkarAlarmHandler(
      play: (type) async {
        played.add(type);
        return AdhkarDeliveryResult.success;
      },
      readPresence: () async => presence,
      speakerConnected: () async => speaker,
      castBusy: () async => busy,
      log:
          ({
            required outcome,
            required type,
            required scheduledAtMs,
            detail,
          }) async {
            outcomes.add(outcome);
            details.add(detail);
          },
      sync: () async {
        syncs += 1;
      },
      wait: (delay) async {
        waits.add(delay);
      },
    );
  }

  test('plays when home and the speaker is connected', () async {
    await build().onFired(AdhkarType.evening, scheduledEpochMs: 10);
    expect(played, [AdhkarType.evening]);
    expect(outcomes, [Outcome.adhkarPlayed]);
    expect(syncs, 1);
    expect(waits, isEmpty);
  });

  test('skips when presence is away', () async {
    presence = PresenceState.away;
    await build().onFired(AdhkarType.morning, scheduledEpochMs: 11);
    expect(played, isEmpty);
    expect(outcomes, [Outcome.adhkarSkippedAway]);
    expect(details, ['away']);
    expect(syncs, 1);
  });

  test('skips when presence is unknown', () async {
    presence = PresenceState.unknown;
    await build().onFired(AdhkarType.morning, scheduledEpochMs: 12);
    expect(played, isEmpty);
    expect(outcomes, [Outcome.adhkarSkippedAway]);
    expect(syncs, 1);
  });

  test('skips when the speaker is offline', () async {
    speaker = false;
    await build().onFired(AdhkarType.evening, scheduledEpochMs: 13);
    expect(played, isEmpty);
    expect(outcomes, [Outcome.adhkarSkippedOffline]);
    expect(syncs, 1);
  });

  test('retries once after 2 minutes when Cast is busy', () async {
    var calls = 0;
    final handler = AdhkarAlarmHandler(
      play: (type) async {
        played.add(type);
        return AdhkarDeliveryResult.success;
      },
      readPresence: () async => PresenceState.home,
      speakerConnected: () async => true,
      castBusy: () async {
        calls += 1;
        return calls == 1;
      },
      log:
          ({
            required outcome,
            required type,
            required scheduledAtMs,
            detail,
          }) async {
            outcomes.add(outcome);
          },
      sync: () async {
        syncs += 1;
      },
      wait: (delay) async {
        waits.add(delay);
      },
    );
    await handler.onFired(AdhkarType.evening, scheduledEpochMs: 14);
    expect(waits, [const Duration(minutes: 2)]);
    expect(played, [AdhkarType.evening]);
    expect(outcomes, [Outcome.adhkarPlayed]);
    expect(syncs, 1);
  });

  test('does not interrupt a still-busy Cast session', () async {
    busy = true;
    await build().onFired(AdhkarType.evening, scheduledEpochMs: 15);
    expect(waits, [const Duration(minutes: 2)]);
    expect(played, isEmpty);
    expect(outcomes, [Outcome.adhkarFailed]);
    expect(details, ['cast busy']);
    expect(syncs, 1);
  });
}
