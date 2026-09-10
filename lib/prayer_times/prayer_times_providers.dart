import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/coordinator/active_delivery_hero.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

import 'adhan_next_prayer_provider.dart';
import 'aladhan_client.dart';
import 'prayer_prefs.dart';

/// Injected after [HomeDeliveryRuntime.bootstrap] (shared with coordinator).
final activeDeliveryHeroProvider = Provider<ActiveDeliveryHero>((ref) {
  throw UnimplementedError(
    'Override activeDeliveryHeroProvider with the runtime instance',
  );
});

/// Live prayer this device is delivering, or null.
final activeDeliveryPrayerProvider = Provider.autoDispose<NextPrayer?>((ref) {
  final hero = ref.watch(activeDeliveryHeroProvider);
  void tick() => ref.invalidateSelf();
  hero.listenable.addListener(tick);
  ref.onDispose(() => hero.listenable.removeListener(tick));
  return hero.current;
});

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

final prayerPrefsProvider = FutureProvider<PrayerPrefs>((ref) {
  return ref.watch(prayerPrefsStoreProvider).read();
});

final nextPrayerSnapshotProvider =
    FutureProvider.autoDispose<NextPrayer?>((ref) async {
  final prefs = await ref.watch(prayerPrefsProvider.future);
  if (!prefs.configured) return null;
  return ref.watch(adhanNextPrayerProvider).next(after: DateTime.now());
});

/// Re-resolve home next-adhan UI after resume / notification open.
///
/// UI-only: does not arm alarms, touch [PrayerDeliveryCoordinator], or clear
/// the schedule engine cache.
void refreshNextPrayerHomeUi(WidgetRef ref) {
  ref.invalidate(nextPrayerSnapshotProvider);
}

final todayScheduleProvider =
    FutureProvider.autoDispose<AladhanDaySchedule>((ref) async {
  final prefs = await ref.watch(prayerPrefsProvider.future);
  return ref.watch(adhanNextPrayerProvider).scheduleForDay(
        prefs: prefs,
        day: DateTime.now(),
      );
});
