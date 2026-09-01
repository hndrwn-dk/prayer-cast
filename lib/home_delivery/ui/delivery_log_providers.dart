import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/delivery_database.dart';
import '../logging/delivery_log_dao.dart';
import '../platform/oem_battery_settings.dart';

/// Injected by the app shell (file DB) or overridden in tests (memory DB).
final deliveryDatabaseProvider = Provider<DeliveryDatabase>((ref) {
  throw UnimplementedError(
    'Override deliveryDatabaseProvider with openDeliveryDatabase()',
  );
});

final deliveryLogDaoProvider = Provider<DeliveryLogDao>((ref) {
  return DeliveryLogDao(ref.watch(deliveryDatabaseProvider));
});

final oemBatterySettingsProvider = Provider<OemBatterySettingsPlatform>((ref) {
  return OemBatterySettings();
});

/// Show battery-unrestricted prompt when optimisation is still enabled.
final batteryUnrestrictedProvider = FutureProvider<bool>((ref) {
  return ref.watch(oemBatterySettingsProvider).isBatteryUnrestricted();
});

/// Last 30 delivery attempts, newest first (§6.3).
final deliveryLogLatestProvider =
    FutureProvider.autoDispose<List<DeliveryLog>>((ref) {
  return ref.watch(deliveryLogDaoProvider).latest(limit: 30);
});

/// Count of FAILED_ALARM_MISSED in the last 7 days (§6.3 OEM nudge).
final failedAlarmMissedWeekProvider = FutureProvider.autoDispose<int>((ref) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ref.watch(deliveryLogDaoProvider).countFailedAlarmMissedSince(
        nowEpochMs: now,
      );
});
