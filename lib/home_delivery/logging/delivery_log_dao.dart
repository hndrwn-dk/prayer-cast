import 'package:drift/drift.dart';

import 'delivery_database.dart';
import 'outcome.dart';

/// Read/write access to `delivery_log` (§6.1, §6.3).
///
/// WHY: The orchestrator records one row per attempt with a typed [Outcome].
/// The UI reads the last 30 rows and scans for repeated `FAILED_ALARM_MISSED`
/// to surface OEM battery settings. Keeping SQL here isolates Drift from the
/// rest of the layer.
final class DeliveryLogDao {
  DeliveryLogDao(this._db);

  final DeliveryDatabase _db;

  /// Insert one attempt. Returns the new row id.
  Future<int> insertAttempt({
    required String sessionId,
    required String prayer,
    required int scheduledAtMs,
    required Outcome outcome,
    int? firedAtMs,
    String? presenceState,
    String? presenceSignal,
    String? role,
    int? peerCount,
    String? targetId,
    String? targetName,
    String? detail,
    int? latencyMs,
  }) {
    return _db.into(_db.deliveryLogs).insert(
          DeliveryLogsCompanion.insert(
            sessionId: sessionId,
            prayer: prayer,
            scheduledAt: scheduledAtMs,
            outcome: outcome.code,
            firedAt: Value(firedAtMs),
            presenceState: Value(presenceState),
            presenceSignal: Value(presenceSignal),
            role: Value(role),
            peerCount: Value(peerCount),
            targetId: Value(targetId),
            targetName: Value(targetName),
            detail: Value(detail),
            latencyMs: Value(latencyMs),
          ),
        );
  }

  /// Most recent [limit] attempts, newest first (§6.3: last 30).
  Future<List<DeliveryLog>> latest({int limit = 30}) {
    final query = _db.select(_db.deliveryLogs)
      ..orderBy([
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  /// Count of [Outcome.failedAlarmMissed] rows with `scheduled_at` in the
  /// last [windowMs] (default 7 days). Used by Phase 6 OEM battery nudge.
  Future<int> countFailedAlarmMissedSince({
    required int nowEpochMs,
    int windowMs = 7 * 24 * 60 * 60 * 1000,
  }) async {
    final since = nowEpochMs - windowMs;
    final query = _db.select(_db.deliveryLogs)
      ..where(
        (t) =>
            t.outcome.equals(Outcome.failedAlarmMissed.code) &
            t.scheduledAt.isBiggerOrEqualValue(since),
      );
    final rows = await query.get();
    return rows.length;
  }
}
