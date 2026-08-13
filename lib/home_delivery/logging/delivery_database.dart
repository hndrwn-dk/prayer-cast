import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'delivery_log_table.dart';

part 'delivery_database.g.dart';

/// Local Drift database holding the delivery log (§6.1).
///
/// WHY: The orchestrator (Phase 4) and delivery-log UI (Phase 6) share one
/// schema. Opening with an injected [QueryExecutor] keeps unit tests on an
/// in-memory DB and leaves file-path selection to the app shell — no
/// `path_provider` dependency inside this layer.
@DriftDatabase(tables: [DeliveryLogs])
class DeliveryDatabase extends _$DeliveryDatabase {
  DeliveryDatabase(super.executor);

  /// In-memory database for unit tests.
  factory DeliveryDatabase.memory() =>
      DeliveryDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
