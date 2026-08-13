import 'package:drift/drift.dart';

/// Drift table for `delivery_log` (spec §6.1).
///
/// WHY: Local-only observability — nothing leaves the device. One row per
/// delivery attempt lets the UI (§6.3) explain misses and detect OEM battery
/// killers (`FAILED_ALARM_MISSED` twice in 7 days).
class DeliveryLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sessionId => text().named('session_id')();

  TextColumn get prayer => text()();

  /// Scheduled azan time, Unix epoch milliseconds.
  IntColumn get scheduledAt => integer().named('scheduled_at')();

  IntColumn get firedAt => integer().named('fired_at').nullable()();

  /// HOME | AWAY | UNKNOWN
  TextColumn get presenceState => text().named('presence_state').nullable()();

  /// A | B | C | D | NONE
  TextColumn get presenceSignal => text().named('presence_signal').nullable()();

  /// LEADER | FOLLOWER | SOLO | PROMOTED
  TextColumn get role => text().nullable()();

  IntColumn get peerCount => integer().named('peer_count').nullable()();

  TextColumn get targetId => text().named('target_id').nullable()();

  TextColumn get targetName => text().named('target_name').nullable()();

  /// See [Outcome.code] (§6.2).
  TextColumn get outcome => text()();

  TextColumn get detail => text().nullable()();

  /// loadMedia call → PLAYING state, milliseconds.
  IntColumn get latencyMs => integer().named('latency_ms').nullable()();
}
