import 'dart:convert';
import 'dart:io';

import '../delivery/cast_client.dart';
import '../presence/fingerprint_store.dart';
import '../presence/lan_fingerprint.dart';

/// Result of a Cast LAN scan for speaker setup.
final class SpeakerScanResult {
  const SpeakerScanResult({required this.devices});

  final List<CastReceiver> devices;

  Map<String, Object?> toJson() => {
    'devices': [
      for (final d in devices)
        {
          'deviceId': d.deviceId,
          'friendlyName': d.friendlyName,
          'host': d.host.address,
        },
    ],
  };

  String toCacheJson() => jsonEncode(toJson());

  /// Reconstructs receivers from disk. Null means missing or corrupt cache.
  static SpeakerScanResult? fromCacheJson(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final devicesRaw = decoded['devices'];
      if (devicesRaw is! List) return const SpeakerScanResult(devices: []);
      final devices = <CastReceiver>[];
      for (final item in devicesRaw) {
        if (item is! Map) continue;
        final id = item['deviceId'];
        final name = item['friendlyName'];
        final host = item['host'];
        if (id is! String || name is! String || host is! String) continue;
        if (id.isEmpty || host.isEmpty) continue;
        final address = InternetAddress.tryParse(host);
        if (address == null) continue;
        devices.add(
          CastReceiver(deviceId: id, friendlyName: name, host: address),
        );
      }
      return SpeakerScanResult(devices: devices);
    } catch (_) {
      return null;
    }
  }
}

/// Saved home speaker snapshot for UI.
final class SavedHomeSpeaker {
  const SavedHomeSpeaker({required this.deviceId, this.friendlyName});

  final String deviceId;
  final String? friendlyName;

  String get displayName {
    final name = friendlyName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return deviceId;
  }

  /// Cast id missing but friendly name survived — show name, prompt re-link.
  bool get needsRelink =>
      deviceId.isEmpty && (friendlyName?.trim().isNotEmpty ?? false);

  bool get hasCastTarget => deviceId.isNotEmpty;
}

/// Onboarding: discover Cast targets and persist Signal A + B (§3.2 / §3.3).
final class HomeOnboarding {
  HomeOnboarding({
    required CastPlatform castPlatform,
    required FingerprintStore store,
    required LanFingerprint lanFingerprint,
  }) : _castPlatform = castPlatform,
       _store = store,
       _lanFingerprint = lanFingerprint;

  final CastPlatform _castPlatform;
  final FingerprintStore _store;
  final LanFingerprint _lanFingerprint;

  static const Duration scanBudget = Duration(seconds: 8);

  Future<SavedHomeSpeaker?> readSavedSpeaker() async {
    var id = await _store.readHomeCastIdResilient();
    final name = await _store.readHomeCastFriendlyName();
    if (id == null || id.isEmpty) {
      id = await _recoverCastIdFromScanCache(name);
    }
    if (id == null || id.isEmpty) {
      final trimmed = name?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return SavedHomeSpeaker(deviceId: '', friendlyName: trimmed);
      }
      return null;
    }
    return SavedHomeSpeaker(deviceId: id, friendlyName: name);
  }

  Future<String?> _recoverCastIdFromScanCache(String? friendlyName) async {
    final wanted = friendlyName?.trim();
    if (wanted == null || wanted.isEmpty) return null;
    final cached = await readCachedSpeakerScan();
    if (cached == null || cached.devices.isEmpty) return null;
    for (final device in cached.devices) {
      if (device.friendlyName == wanted) {
        await _store.writeHomeCastId(device.deviceId);
        return device.deviceId;
      }
    }
    return null;
  }

  Future<SpeakerScanResult> scanSpeakers({Duration budget = scanBudget}) async {
    final devices = await _castPlatform.discover(budget: budget);
    return SpeakerScanResult(devices: List<CastReceiver>.from(devices));
  }

  /// Last successful scan, including a genuine empty list. Null if never scanned.
  Future<SpeakerScanResult?> readCachedSpeakerScan() async {
    final raw = await _store.readLastSpeakerScanJson();
    if (raw == null) return null;
    return SpeakerScanResult.fromCacheJson(raw);
  }

  Future<void> writeCachedSpeakerScan(SpeakerScanResult result) async {
    await _store.writeLastSpeakerScanJson(result.toCacheJson());
  }

  /// Persist Cast id (Signal A), friendly name, and LAN fingerprint (Signal B).
  Future<CapturedFingerprint> saveHomeSpeaker(CastReceiver receiver) async {
    await _store.writeHomeCastId(receiver.deviceId);
    await _store.writeHomeCastFriendlyName(receiver.friendlyName);
    return _lanFingerprint.captureHome();
  }

  /// Clear the saved Cast target only (Signal A).
  ///
  /// Leaves LAN fingerprint hashes, per-install salt, household election
  /// secret, and the last speaker-scan cache in place. Presence then falls
  /// back to Signal B until a new speaker is saved.
  Future<void> clearHomeSpeaker() async {
    await _store.writeHomeCastId('');
    await _store.writeHomeCastFriendlyName('');
  }

  /// Drop devices from the last scan cache. They reappear on the next live scan.
  ///
  /// Does not touch the physical Cast device or the saved home speaker.
  Future<void> removeDevicesFromCachedScan(Iterable<String> deviceIds) async {
    final drop = deviceIds.toSet();
    if (drop.isEmpty) return;
    final cached = await readCachedSpeakerScan();
    if (cached == null) return;
    final kept = [
      for (final device in cached.devices)
        if (!drop.contains(device.deviceId)) device,
    ];
    if (kept.length == cached.devices.length) return;
    await writeCachedSpeakerScan(SpeakerScanResult(devices: kept));
  }
}
