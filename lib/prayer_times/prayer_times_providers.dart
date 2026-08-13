import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

import 'adhan_next_prayer_provider.dart';
import 'aladhan_client.dart';
import 'prayer_prefs.dart';

/// Injected by the app shell after prefs file is opened.
final prayerPrefsStoreProvider = Provider<PrayerPrefsStore>((ref) {
  throw UnimplementedError(
    'Override prayerPrefsStoreProvider with FilePrayerPrefsStore',
  );
});

/// Shared Aladhan-backed next-prayer engine (same instance as coordinator).
final adhanNextPrayerProvider = Provider<AdhanNextPrayerProvider>((ref) {
  throw UnimplementedError(
    'Override adhanNextPrayerProvider with the runtime instance',
  );
});

/// Injected after [HomeDeliveryRuntime.bootstrap].
final adzanCastTesterProvider = Provider<AdzanCastTester>((ref) {
  throw UnimplementedError(
    'Override adzanCastTesterProvider with HomeDeliveryRuntime.castTester',
  );
});

/// Injected after [HomeDeliveryRuntime.bootstrap].
final localPrayerPlayerProvider = Provider<LocalPrayerPlayer>((ref) {
  throw UnimplementedError(
    'Override localPrayerPlayerProvider with HomeDeliveryRuntime.localPlayer',
  );
});

final prayerPrefsProvider = FutureProvider.autoDispose<PrayerPrefs>((ref) {
  return ref.watch(prayerPrefsStoreProvider).read();
});

final nextPrayerSnapshotProvider =
    FutureProvider.autoDispose<NextPrayer?>((ref) async {
  final prefs = await ref.watch(prayerPrefsProvider.future);
  if (!prefs.configured) return null;
  return ref.watch(adhanNextPrayerProvider).next(after: DateTime.now());
});

final todayScheduleProvider =
    FutureProvider.autoDispose<AladhanDaySchedule>((ref) async {
  final prefs = await ref.watch(prayerPrefsProvider.future);
  return ref.watch(adhanNextPrayerProvider).scheduleForDay(
        prefs: prefs,
        day: DateTime.now(),
      );
});
