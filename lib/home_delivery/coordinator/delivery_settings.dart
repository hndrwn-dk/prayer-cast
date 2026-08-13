import '../presence/fingerprint_store.dart';

/// Cast target + playback volume for a delivery attempt.
///
/// WHY: No dedicated settings screen exists yet. The saved home Cast id already
/// lives on [FingerprintStore] (Signal A). Volume defaults until a real
/// settings surface lands — do not invent a parallel prefs store for cast id.
abstract interface class DeliverySettings {
  Future<String?> homeCastDeviceId();

  Future<double> playbackVolume();
}

/// Reads Cast id from [FingerprintStore]. [defaultVolume] is only used
/// when the speaker is muted — an audible receiver volume is left as-is.
final class FingerprintBackedDeliverySettings implements DeliverySettings {
  FingerprintBackedDeliverySettings(
    this._store, {
    this.defaultVolume = 0.7,
  });

  final FingerprintStore _store;
  final double defaultVolume;

  @override
  Future<String?> homeCastDeviceId() => _store.readHomeCastId();

  @override
  Future<double> playbackVolume() async => defaultVolume;
}
