import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../coordinator/home_onboarding.dart';
import '../platform/nearby_wifi_scan_permission.dart';
import '../presence/fingerprint_store.dart';
import '../presence/presence_service.dart';
import '../presence/presence_state.dart';

/// Android 13+ nearby-Wi-Fi grant before Cast / NSD scan. Not location.
final nearbyWifiScanPermissionProvider = Provider<NearbyWifiScanPermission>((
  ref,
) {
  return const NearbyWifiScanPermission();
});

/// Injected by the app shell after [HomeDeliveryRuntime.bootstrap].
final homeOnboardingProvider = Provider<HomeOnboarding>((ref) {
  throw UnimplementedError(
    'Override homeOnboardingProvider with HomeDeliveryRuntime.onboarding',
  );
});

/// Production [PresenceService] for LAN/Cast home detection (no GPS).
///
/// Null in widget tests / shells that do not bootstrap presence.
final presenceServiceProvider = Provider<PresenceService?>((ref) => null);

/// File-backed fingerprint store from [HomeDeliveryRuntime.bootstrap].
final fingerprintStoreProvider = Provider<FingerprintStore>((ref) {
  throw UnimplementedError(
    'Override fingerprintStoreProvider with HomeDeliveryRuntime.fingerprintStore',
  );
});

/// Saved home Cast speaker (Signal A), if any.
final savedHomeSpeakerProvider = FutureProvider.autoDispose<SavedHomeSpeaker?>((
  ref,
) {
  return ref.watch(homeOnboardingProvider).readSavedSpeaker();
});

/// Cast LAN discovery for the Home speaker picker.
///
/// Kept for the ProviderScope lifetime (no autoDispose) so leaving and
/// re-opening Speaker Setup shows the last scan instead of rescanning.
/// Disk cache survives app kill; [speakerScanEpochProvider] forces a live
/// discover on refresh / retry. Bound to [HomeOnboarding.scanBudget]
/// so discovery cannot spin forever.
final speakerScanEpochProvider = StateProvider<int>((_) => 0);

/// Device ids hidden from Speaker Setup until the next live rescan.
///
/// Survives leaving the page in the same session. Cleared on rescan.
/// Disk cache is updated separately so a cold start also stays hidden.
final hiddenSpeakerIdsProvider = StateProvider<Set<String>>((_) => const {});

final speakerDiscoveryProvider = FutureProvider<SpeakerScanResult>((ref) async {
  final epoch = ref.watch(speakerScanEpochProvider);
  final onboarding = ref.watch(homeOnboardingProvider);

  if (epoch == 0) {
    final cached = await onboarding.readCachedSpeakerScan();
    if (cached != null) return cached;
  }

  try {
    final allowed = await ref
        .read(nearbyWifiScanPermissionProvider)
        .ensureGranted();
    if (!allowed) {
      throw StateError('local network permission denied');
    }
    final result = await onboarding.scanSpeakers(
      budget: HomeOnboarding.scanBudget,
    );
    await onboarding.writeCachedSpeakerScan(result);
    return result;
  } catch (_) {
    final cached = await onboarding.readCachedSpeakerScan();
    if (cached != null) return cached;
    rethrow;
  }
});

/// Whether the saved home speaker appeared in the last scan cache.
final savedSpeakerReachableProvider =
    FutureProvider.autoDispose<bool?>((ref) async {
  final saved = await ref.watch(savedHomeSpeakerProvider.future);
  if (saved == null) return null;
  final cached = await ref.read(homeOnboardingProvider).readCachedSpeakerScan();
  if (cached == null) return null;
  return cached.devices.any((d) => d.deviceId == saved.deviceId);
});

/// Home presence for the status chip — Signal A (saved Cast) then B (LAN fp).
///
/// Returns [PresenceState.unknown] when no speaker is configured, or when
/// presence is not wired (tests). Never invents GPS geofence presence.
final homePresenceProvider = FutureProvider.autoDispose<PresenceState>((
  ref,
) async {
  final speaker = await ref.watch(savedHomeSpeakerProvider.future);
  if (speaker == null) return PresenceState.unknown;

  final presence = ref.watch(presenceServiceProvider);
  if (presence == null) return PresenceState.unknown;

  final snapshot = await presence.scan();
  return snapshot.state;
});
