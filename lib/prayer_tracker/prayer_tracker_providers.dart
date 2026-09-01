import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prayer_tracker_stats.dart';
import 'prayer_tracker_store.dart';

final prayerTrackerStoreProvider = Provider<PrayerTrackerStore>((ref) {
  throw UnimplementedError(
    'Override prayerTrackerStoreProvider with FilePrayerTrackerStore',
  );
});

final todayPrayerLogProvider =
    FutureProvider.autoDispose<PrayerDayLog>((ref) async {
  final store = ref.watch(prayerTrackerStoreProvider);
  return store.readDay(FilePrayerTrackerStore.dayKey(DateTime.now()));
});

final prayerStatsPeriodProvider =
    StateProvider<PrayerStatsPeriod>((ref) => PrayerStatsPeriod.week);

final qadhaLedgerProvider = FutureProvider.autoDispose<QadhaLedger>((ref) async {
  final store = ref.watch(prayerTrackerStoreProvider);
  return store.readQadha();
});

final yesterdayUnloggedProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final store = ref.watch(prayerTrackerStoreProvider);
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final log = await store.readDay(FilePrayerTrackerStore.dayKey(yesterday));
  return [
    for (final prayer in kTrackedPrayers)
      if (!(log[prayer]?.isLogged ?? false)) prayer,
  ];
});

final prayerPeriodStatsProvider =
    FutureProvider.autoDispose<PrayerPeriodStats>((ref) async {
  final period = ref.watch(prayerStatsPeriodProvider);
  final store = ref.watch(prayerTrackerStoreProvider);
  final now = DateTime.now();
  final from = PrayerStatsCalculator.startOf(now, period);
  final days = await store.readRange(
    FilePrayerTrackerStore.dayKey(from),
    FilePrayerTrackerStore.dayKey(now),
  );
  return PrayerStatsCalculator.compute(
    now: now,
    period: period,
    days: days,
  );
});
