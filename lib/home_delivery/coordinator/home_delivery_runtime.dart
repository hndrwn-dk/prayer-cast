import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../common/logger.dart';
import '../common/scheduler.dart';
import '../coordination/device_identity.dart';
import '../coordination/peer_registry.dart';
import '../coordination/unicast_transport.dart';
import '../delivery/cast_client.dart';
import '../delivery/delivery_orchestrator.dart';
import '../delivery/interface_selector.dart';
import '../logging/delivery_database.dart';
import '../logging/delivery_log_dao.dart';
import '../platform/device_conditions.dart';
import '../platform/exact_alarm.dart';
import '../presence/fingerprint_store.dart';
import '../presence/mdns_browser.dart';
import '../presence/presence_service.dart';
import 'adzan_audio_loader.dart';
import 'delivery_settings.dart';
import 'next_prayer_provider.dart';
import 'prayer_delivery_coordinator.dart';

/// Production wiring for presence → election → cast + alarm schedule.
///
/// Built once in `main` after the delivery DB is open.
final class HomeDeliveryRuntime {
  HomeDeliveryRuntime._({
    required this.coordinator,
    required this.fingerprintStore,
    required this.exactAlarm,
  });

  final PrayerDeliveryCoordinator coordinator;
  final FingerprintStore fingerprintStore;
  final ExactAlarmPlatform exactAlarm;

  static Future<HomeDeliveryRuntime> bootstrap({
    required DeliveryDatabase database,
    required NextPrayerProvider nextPrayer,
    void Function(bool granted)? onPermissionChanged,
    HomeDeliveryLogger logger = const SilentLogger(),
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final fingerprintStore = FileFingerprintStore(
      File(p.join(docs.path, 'home_fingerprint.json')),
    );
    final deviceIdStore = FileDeviceIdStore(
      File(p.join(docs.path, 'device_id.txt')),
    );

    final exactAlarm = ExactAlarm(logger: logger);
    final scheduler = const WallScheduler();
    final browser = NsdMdnsBrowser(logger: logger);
    final presence = PresenceService(
      browser: browser,
      store: fingerprintStore,
      clock: scheduler,
      logger: logger,
    );
    final identity = DeviceIdentity(store: deviceIdStore, logger: logger);
    final discovery = NsdAdzanDiscovery(logger: logger);
    final transport = await UdpUnicastTransport.bind(logger: logger);
    final castClient = CastClient(
      platform: FlutterCastPlatform(logger: logger),
      logger: logger,
    );
    final orchestrator = DeliveryOrchestrator(
      presence: presence,
      fingerprintStore: fingerprintStore,
      identity: identity,
      discovery: discovery,
      transport: transport,
      castClient: castClient,
      interfaces: InterfaceSelector(logger: logger),
      logDao: DeliveryLogDao(database),
      scheduler: scheduler,
      logger: logger,
    );

    final coordinator = PrayerDeliveryCoordinator(
      exactAlarm: exactAlarm,
      nextPrayer: nextPrayer,
      deviceConditions: MethodChannelDeviceConditions(logger: logger),
      settings: FingerprintBackedDeliverySettings(fingerprintStore),
      audioLoader: AssetAdzanAudioLoader(logger: logger),
      runDelivery: orchestrator.run,
      clock: scheduler,
      onPermissionChanged: onPermissionChanged,
      logger: logger,
    );

    return HomeDeliveryRuntime._(
      coordinator: coordinator,
      fingerprintStore: fingerprintStore,
      exactAlarm: exactAlarm,
    );
  }
}

/// File-backed fingerprint store for production.
final class FileFingerprintStore implements FingerprintStore {
  FileFingerprintStore(this._file);

  final File _file;
  MemoryFingerprintStore _memory = MemoryFingerprintStore();
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (!await _file.exists()) return;
    try {
      final text = await _file.readAsString();
      // Minimal line format: salt\ncastId\nhash1,hash2,...
      final lines = text.split('\n');
      final salt = lines.isNotEmpty && lines[0].isNotEmpty ? lines[0] : null;
      final castId = lines.length > 1 && lines[1].isNotEmpty ? lines[1] : null;
      final hashes = lines.length > 2 && lines[2].isNotEmpty
          ? lines[2].split(',').where((e) => e.isNotEmpty).toSet()
          : <String>{};
      final electionSecret =
          lines.length > 3 && lines[3].isNotEmpty ? lines[3] : null;
      _memory = MemoryFingerprintStore(
        salt: salt,
        hashes: hashes,
        homeCastId: castId,
        electionSecret: electionSecret,
      );
    } catch (_) {
      _memory = MemoryFingerprintStore();
    }
  }

  Future<void> _persist() async {
    await _file.parent.create(recursive: true);
    final salt = await _memory.readSalt() ?? '';
    final castId = await _memory.readHomeCastId() ?? '';
    final hashes = (await _memory.readHashes()).join(',');
    final electionSecret = await _memory.readElectionSecret() ?? '';
    await _file.writeAsString('$salt\n$castId\n$hashes\n$electionSecret\n');
  }

  @override
  Future<String?> readSalt() async {
    await _ensureLoaded();
    return _memory.readSalt();
  }

  @override
  Future<void> writeSalt(String salt) async {
    await _ensureLoaded();
    await _memory.writeSalt(salt);
    await _persist();
  }

  @override
  Future<Set<String>> readHashes() async {
    await _ensureLoaded();
    return _memory.readHashes();
  }

  @override
  Future<void> writeHashes(Set<String> hashes) async {
    await _ensureLoaded();
    await _memory.writeHashes(hashes);
    await _persist();
  }

  @override
  Future<String?> readHomeCastId() async {
    await _ensureLoaded();
    return _memory.readHomeCastId();
  }

  @override
  Future<void> writeHomeCastId(String castId) async {
    await _ensureLoaded();
    await _memory.writeHomeCastId(castId);
    await _persist();
  }

  @override
  Future<String?> readElectionSecret() async {
    await _ensureLoaded();
    return _memory.readElectionSecret();
  }

  @override
  Future<void> writeElectionSecret(String secret) async {
    await _ensureLoaded();
    await _memory.writeElectionSecret(secret);
    await _persist();
  }
}

/// File-backed device id store (random UUID only — never hardware ids).
final class FileDeviceIdStore implements DeviceIdStore {
  FileDeviceIdStore(this._file);

  final File _file;

  @override
  Future<String?> read() async {
    if (!await _file.exists()) return null;
    final value = (await _file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> write(String deviceId) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(deviceId);
  }
}
