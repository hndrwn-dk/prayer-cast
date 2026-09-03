import 'dart:async';
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
import '../presence/lan_fingerprint.dart';
import '../../prayer_times/adhan_next_prayer_provider.dart';
import '../../prayer_times/prayer_prefs.dart';
import 'adzan_audio_loader.dart';
import 'adzan_cast_tester.dart';
import 'audioplayers_local_prayer_player.dart';
import 'delivery_settings.dart';
import 'home_onboarding.dart';
import 'local_prayer_player.dart';
import 'next_prayer_provider.dart';
import 'prayer_delivery_coordinator.dart';
import 'pre_prayer_alert_scheduler.dart';
import 'prayer_delivery_mode_source.dart';

/// Production wiring for presence → election → cast + alarm schedule.
///
/// Built once in `main` after the delivery DB is open.
final class HomeDeliveryRuntime {
  HomeDeliveryRuntime._({
    required this.coordinator,
    required this.fingerprintStore,
    required this.exactAlarm,
    required this.castPlatform,
    required this.lanFingerprint,
    required this.presence,
    required this.onboarding,
    required this.castTester,
    required this.localPlayer,
  });

  final PrayerDeliveryCoordinator coordinator;
  final FingerprintStore fingerprintStore;
  final ExactAlarmPlatform exactAlarm;
  final CastPlatform castPlatform;
  final LanFingerprint lanFingerprint;
  final PresenceService presence;
  final HomeOnboarding onboarding;
  final AdzanCastTester castTester;
  final LocalPrayerPlayer localPlayer;

  static Future<HomeDeliveryRuntime> bootstrap({
    required DeliveryDatabase database,
    required NextPrayerProvider nextPrayer,
    required PrayerPrefsStore prayerPrefs,
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
    unawaited(exactAlarm.syncTravelLocation(enabled: false));
    final scheduler = const WallScheduler();
    final browser = NsdMdnsBrowser(logger: logger);
    final lanFingerprint = LanFingerprint(
      browser: browser,
      store: fingerprintStore,
      logger: logger,
    );
    final presence = PresenceService(
      browser: browser,
      store: fingerprintStore,
      clock: scheduler,
      logger: logger,
    );
    final identity = DeviceIdentity(store: deviceIdStore, logger: logger);
    final discovery = NsdAdzanDiscovery(logger: logger);
    final transport = await UdpUnicastTransport.bind(logger: logger);
    final castPlatform = FlutterCastPlatform(logger: logger);
    final castClient = CastClient(platform: castPlatform, logger: logger);
    final audioLoader = AssetAdzanAudioLoader(logger: logger);
    final localPlayer = AudioplayersLocalPrayerPlayer(
      audioLoader: audioLoader,
      logger: logger,
      nativeBeep: exactAlarm.playLocalBeep,
      nativeTakbir: exactAlarm.playLocalTakbir,
    );
    final castTester = AdzanCastTester(
      castClient: castClient,
      store: fingerprintStore,
      audioLoader: audioLoader,
      interfaces: InterfaceSelector(logger: logger),
      logger: logger,
    );
    final onboarding = HomeOnboarding(
      castPlatform: castPlatform,
      store: fingerprintStore,
      lanFingerprint: lanFingerprint,
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
      audioLoader: audioLoader,
      runDelivery: orchestrator.run,
      clock: scheduler,
      deliveryModes: PrefsPrayerDeliveryModeSource(prayerPrefs),
      localPlayer: localPlayer,
      logDao: DeliveryLogDao(database),
      prePrayerAlerts: PrePrayerAlertScheduler(
        exactAlarm: exactAlarm,
        prayerPrefs: prayerPrefs,
        readLocaleCode: () async {
          final docs = await getApplicationDocumentsDirectory();
          final localeFile = File(p.join(docs.path, 'app_locale.txt'));
          if (!await localeFile.exists()) return null;
          try {
            final raw = (await localeFile.readAsString()).trim();
            if (raw == 'en' || raw == 'id') return raw;
          } catch (_) {}
          return null;
        },
      ),
      readLocaleCode: () async {
        final docs = await getApplicationDocumentsDirectory();
        final localeFile = File(p.join(docs.path, 'app_locale.txt'));
        if (!await localeFile.exists()) return null;
        try {
          final raw = (await localeFile.readAsString()).trim();
          if (raw == 'en' || raw == 'id') return raw;
        } catch (_) {}
        return null;
      },
      onPermissionChanged: onPermissionChanged,
      logger: logger,
    );

    return HomeDeliveryRuntime._(
      coordinator: coordinator,
      fingerprintStore: fingerprintStore,
      exactAlarm: exactAlarm,
      castPlatform: castPlatform,
      lanFingerprint: lanFingerprint,
      presence: presence,
      onboarding: onboarding,
      castTester: castTester,
      localPlayer: localPlayer,
    );
  }
}

/// File-backed fingerprint store for production.
final class FileFingerprintStore implements FingerprintStore {
  FileFingerprintStore(this._file);

  final File _file;
  MemoryFingerprintStore _memory = MemoryFingerprintStore();
  bool _loaded = false;

  File get _backupFile => File('${_file.parent.path}/home_cast_backup.txt');

  File get _speakerScanFile =>
      File('${_file.parent.path}/home_speaker_scan.json');

  /// Drop in-memory cache so the next read reflects on-disk state.
  ///
  /// Call when the app resumes — another process must not clobber this file,
  /// but a headless alarm pass may have updated election hashes while the UI
  /// still holds a stale empty cast id in memory.
  Future<void> reloadFromDisk() async {
    _loaded = false;
    _memory = MemoryFingerprintStore();
    await _ensureLoaded();
    await _healCastIdFromBackup();
  }

  Future<void> _healCastIdFromBackup() async {
    final id = await _memory.readHomeCastId();
    if (id != null && id.isNotEmpty) return;
    final backup = await _readBackup();
    if (backup == null) return;
    await _memory.writeHomeCastId(backup.$1);
    if (backup.$2.isNotEmpty) {
      final name = await _memory.readHomeCastFriendlyName();
      if (name == null || name.isEmpty) {
        await _memory.writeHomeCastFriendlyName(backup.$2);
      }
    }
    await _persist(allowEmptyCastId: false);
  }

  Future<(String, String)?> _readBackup() async {
    if (!await _backupFile.exists()) return null;
    try {
      final lines = (await _backupFile.readAsString()).split('\n');
      final id = lines.isNotEmpty ? lines[0].trim() : '';
      final name = lines.length > 1 ? lines[1].trim() : '';
      if (id.isEmpty) return null;
      return (id, name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeBackup(String castId, String friendlyName) async {
    await _file.parent.create(recursive: true);
    await _backupFile.writeAsString('$castId\n$friendlyName\n');
  }

  Future<void> _clearBackup() async {
    if (await _backupFile.exists()) {
      await _backupFile.delete();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    String? salt;
    String? castId;
    var hashes = <String>{};
    String? electionSecret;
    String? friendlyName;
    String? scanJson;
    if (await _file.exists()) {
      try {
        final text = await _file.readAsString();
        // Minimal line format: salt\ncastId\nhash1,hash2,...
        final lines = text.split('\n');
        salt = lines.isNotEmpty && lines[0].isNotEmpty ? lines[0] : null;
        castId = lines.length > 1 && lines[1].isNotEmpty ? lines[1] : null;
        hashes = lines.length > 2 && lines[2].isNotEmpty
            ? lines[2].split(',').where((e) => e.isNotEmpty).toSet()
            : <String>{};
        electionSecret = lines.length > 3 && lines[3].isNotEmpty
            ? lines[3]
            : null;
        friendlyName = lines.length > 4 && lines[4].isNotEmpty
            ? lines[4]
            : null;
      } catch (_) {}
    }
    if (await _speakerScanFile.exists()) {
      try {
        final text = (await _speakerScanFile.readAsString()).trim();
        if (text.isNotEmpty) scanJson = text;
      } catch (_) {}
    }
    _memory = MemoryFingerprintStore(
      salt: salt,
      hashes: hashes,
      homeCastId: castId,
      homeCastFriendlyName: friendlyName,
      electionSecret: electionSecret,
      lastSpeakerScanJson: scanJson,
    );
    if (castId != null && castId.isNotEmpty && !await _backupFile.exists()) {
      await _writeBackup(castId, friendlyName ?? '');
    }
  }

  Future<void> _persist({bool allowEmptyCastId = false}) async {
    await _file.parent.create(recursive: true);
    var castId = await _memory.readHomeCastId() ?? '';
    if (!allowEmptyCastId && castId.isEmpty) {
      castId = await _readCastIdLineFromDisk() ?? '';
      if (castId.isEmpty) {
        final backup = await _readBackup();
        if (backup != null) castId = backup.$1;
      }
      if (castId.isNotEmpty) {
        await _memory.writeHomeCastId(castId);
      }
    }
    final salt = await _memory.readSalt() ?? '';
    final hashes = (await _memory.readHashes()).join(',');
    final electionSecret = await _memory.readElectionSecret() ?? '';
    final friendlyName = await _memory.readHomeCastFriendlyName() ?? '';
    final payload =
        '$salt\n$castId\n$hashes\n$electionSecret\n$friendlyName\n';
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(payload);
    if (await _file.exists()) {
      await _file.delete();
    }
    await temp.rename(_file.path);
  }

  Future<String?> _readCastIdLineFromDisk() async {
    if (!await _file.exists()) return null;
    try {
      final lines = (await _file.readAsString()).split('\n');
      if (lines.length < 2) return null;
      final id = lines[1].trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSpeakerScan() async {
    await _file.parent.create(recursive: true);
    final json = await _memory.readLastSpeakerScanJson();
    if (json == null || json.isEmpty) {
      if (await _speakerScanFile.exists()) {
        await _speakerScanFile.delete();
      }
      return;
    }
    await _speakerScanFile.writeAsString(json);
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
    await _persist(allowEmptyCastId: false);
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
    await _persist(allowEmptyCastId: false);
  }

  @override
  Future<String?> readHomeCastId() async {
    await _ensureLoaded();
    return _memory.readHomeCastId();
  }

  @override
  Future<String?> readHomeCastIdResilient() async {
    await _ensureLoaded();
    var id = await _memory.readHomeCastId();
    if (id != null && id.isNotEmpty) return id;
    await _healCastIdFromBackup();
    id = await _memory.readHomeCastId();
    if (id != null && id.isNotEmpty) return id;
    final disk = await _readCastIdLineFromDisk();
    if (disk != null && disk.isNotEmpty) {
      await _memory.writeHomeCastId(disk);
      return disk;
    }
    return null;
  }

  @override
  Future<void> writeHomeCastId(String castId) async {
    await _ensureLoaded();
    await _memory.writeHomeCastId(castId);
    final allowEmpty = castId.isEmpty;
    await _persist(allowEmptyCastId: allowEmpty);
    if (castId.isNotEmpty) {
      final name = await _memory.readHomeCastFriendlyName() ?? '';
      await _writeBackup(castId, name);
    } else {
      await _clearBackup();
    }
  }

  @override
  Future<String?> readHomeCastFriendlyName() async {
    await _ensureLoaded();
    return _memory.readHomeCastFriendlyName();
  }

  @override
  Future<void> writeHomeCastFriendlyName(String name) async {
    await _ensureLoaded();
    await _memory.writeHomeCastFriendlyName(name);
    await _persist(allowEmptyCastId: false);
    final id = await _memory.readHomeCastId();
    if (id != null && id.isNotEmpty) {
      await _writeBackup(id, name);
    }
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
    await _persist(allowEmptyCastId: false);
  }

  @override
  Future<String?> readLastSpeakerScanJson() async {
    await _ensureLoaded();
    return _memory.readLastSpeakerScanJson();
  }

  @override
  Future<void> writeLastSpeakerScanJson(String json) async {
    await _ensureLoaded();
    await _memory.writeLastSpeakerScanJson(json);
    await _persistSpeakerScan();
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
