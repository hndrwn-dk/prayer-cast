import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_log_dao.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';

void main() {
  late DeliveryDatabase db;
  late DeliveryLogDao dao;

  setUp(() {
    db = DeliveryDatabase.memory();
    dao = DeliveryLogDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts a row with Outcome code and reads latest', () async {
    await dao.insertAttempt(
      sessionId: 'abc123def4567890',
      prayer: 'maghrib',
      scheduledAtMs: 1786353600000,
      outcome: Outcome.played,
      role: 'SOLO',
      peerCount: 0,
      presenceState: 'HOME',
      presenceSignal: 'A',
    );

    final rows = await dao.latest();
    expect(rows, hasLength(1));
    expect(rows.single.outcome, Outcome.played.code);
    expect(rows.single.prayer, 'maghrib');
    expect(rows.single.role, 'SOLO');
  });

  test('latest returns at most the requested limit, newest first', () async {
    for (var i = 0; i < 5; i++) {
      await dao.insertAttempt(
        sessionId: 'session-$i'.padRight(16, '0'),
        prayer: 'fajr',
        scheduledAtMs: 1786353600000 + i,
        outcome: Outcome.suppressedAway,
      );
    }

    final rows = await dao.latest(limit: 3);
    expect(rows, hasLength(3));
    expect(rows.map((r) => r.scheduledAt).toList(), [
      1786353600004,
      1786353600003,
      1786353600002,
    ]);
  });

  test('counts FAILED_ALARM_MISSED inside the 7-day window', () async {
    const now = 1786353600000;
    const day = 24 * 60 * 60 * 1000;

    await dao.insertAttempt(
      sessionId: 'missed-recent000',
      prayer: 'fajr',
      scheduledAtMs: now - (2 * day),
      outcome: Outcome.failedAlarmMissed,
    );
    await dao.insertAttempt(
      sessionId: 'missed-old000000',
      prayer: 'fajr',
      scheduledAtMs: now - (10 * day),
      outcome: Outcome.failedAlarmMissed,
    );
    await dao.insertAttempt(
      sessionId: 'played-recent000',
      prayer: 'maghrib',
      scheduledAtMs: now - day,
      outcome: Outcome.played,
    );

    expect(
      await dao.countFailedAlarmMissedSince(nowEpochMs: now),
      1,
    );
  });

  test('Outcome.fromCode round-trips every §6.2 code', () {
    for (final value in Outcome.values) {
      expect(Outcome.fromCode(value.code), value);
    }
  });
}
