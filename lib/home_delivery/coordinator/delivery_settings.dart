import '../presence/fingerprint_store.dart';

/// Cast target for a delivery attempt.
///
/// Volume is read from [PrayerPrefs.volumeFor] in the coordinator — null means
/// leave the speaker alone. This store only supplies the home Cast id.
abstract interface class DeliverySettings {
  Future<String?> homeCastDeviceId();
}

/// Reads Cast id from [FingerprintStore].
final class FingerprintBackedDeliverySettings implements DeliverySettings {
  FingerprintBackedDeliverySettings(this._store);

  final FingerprintStore _store;

  @override
  Future<String?> homeCastDeviceId() => _store.readHomeCastIdResilient();
}
