import 'dart:math';

import '../common/logger.dart';

/// Persists a random UUIDv4 `deviceId` and computes election priority (§4.3, §4.4).
///
/// WHY: Peers rank by `(priority, deviceId)`. The id is a household coordination
/// token only — never IMEI, MAC, IDFV, Android ID, or any derivation of them
/// (hard requirement #6 / §4.3). Priority is recomputed fresh each election
/// from live device conditions so a phone that just entered battery saver
/// correctly drops to 0 and yields.
final class DeviceIdentity {
  DeviceIdentity({
    required DeviceIdStore store,
    HomeDeliveryLogger logger = const SilentLogger(),
    UuidGenerator uuidGenerator = const SecureUuidV4Generator(),
  })  : _store = store,
        _logger = logger,
        _uuidGenerator = uuidGenerator;

  final DeviceIdStore _store;
  final HomeDeliveryLogger _logger;
  final UuidGenerator _uuidGenerator;

  String? _cachedId;

  /// Returns the persisted device id, generating and storing one on first use.
  Future<String> deviceId() async {
    if (_cachedId != null) return _cachedId!;

    final existing = await _store.read();
    if (existing != null && existing.isNotEmpty) {
      _cachedId = existing;
      return existing;
    }

    final created = _uuidGenerator.generate();
    await _store.write(created);
    _cachedId = created;
    _logger.info('Generated new deviceId', tag: 'DeviceIdentity');
    return created;
  }

  /// Priority 0–100 per §4.4. Higher wins; tie-break is lexicographic deviceId.
  ///
  /// Battery saver OR clock skew ⇒ 0 (never leads), regardless of other state.
  int priority(DeviceConditions conditions) {
    if (conditions.batterySaverActive || conditions.clockSkewDetected) {
      return 0;
    }
    if (conditions.isHub) {
      return 100;
    }
    switch (conditions.formFactor) {
      case DeviceFormFactor.tablet:
        if (conditions.isPluggedIn && conditions.isScreenOn) {
          return 60;
        }
        // Spec table only lists "Tablet, plugged in, screen on". A tablet that
        // is unplugged or screen-off is treated like a phone of the same
        // power state so it still participates with a deterministic rank.
        if (conditions.isPluggedIn) {
          return 40;
        }
        return conditions.batteryPercent > 50 ? 25 : 10;
      case DeviceFormFactor.phone:
        if (conditions.isPluggedIn) {
          return 40;
        }
        return conditions.batteryPercent > 50 ? 25 : 10;
    }
  }

  /// Lexicographic compare of two device ids (spec §4.4 tie-break).
  static int compareDeviceIds(String a, String b) => a.compareTo(b);

  /// Rank key: higher priority first, then lexicographically smaller deviceId.
  /// Returns negative if [a] should rank above [b].
  static int compareRank(PeerRank a, PeerRank b) {
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    return a.deviceId.compareTo(b.deviceId);
  }
}

/// Live inputs for §4.4 priority. Computed by the platform layer each election.
final class DeviceConditions {
  const DeviceConditions({
    required this.formFactor,
    required this.isPluggedIn,
    required this.isScreenOn,
    required this.batteryPercent,
    required this.batterySaverActive,
    required this.clockSkewDetected,
    this.isHub = false,
  });

  /// Dedicated hub / headless companion build (§4.4 row 1).
  final bool isHub;

  final DeviceFormFactor formFactor;
  final bool isPluggedIn;
  final bool isScreenOn;

  /// 0–100 inclusive.
  final int batteryPercent;
  final bool batterySaverActive;
  final bool clockSkewDetected;
}

enum DeviceFormFactor { phone, tablet }

/// Rank tuple used by the election (§4.6).
final class PeerRank {
  const PeerRank({required this.deviceId, required this.priority});

  final String deviceId;
  final int priority;
}

/// Persistence port for the random device id. Implementations must not derive
/// the value from any hardware identifier.
abstract interface class DeviceIdStore {
  Future<String?> read();

  Future<void> write(String deviceId);
}

/// In-memory store for unit tests.
final class MemoryDeviceIdStore implements DeviceIdStore {
  MemoryDeviceIdStore([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String deviceId) async {
    _value = deviceId;
  }
}

/// Generates a UUIDv4 string. Kept as a port so tests can inject fixed ids.
abstract interface class UuidGenerator {
  String generate();
}

/// RFC 4122 variant-1 UUIDv4 from [Random.secure]. Never reads hardware IDs.
final class SecureUuidV4Generator implements UuidGenerator {
  const SecureUuidV4Generator();

  @override
  String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Version 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant 10xx
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-'
        '${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-'
        '${h.substring(20)}';
  }
}
