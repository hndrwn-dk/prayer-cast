import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_delivery_runtime.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';

import '../delivery/cast_client_test.dart';
import '../presence/fake_mdns_browser.dart';

void main() {
  test('writeHashes does not wipe cast id from disk', () async {
    final dir = await Directory.systemTemp.createTemp('fp_guard_');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileFingerprintStore(File('${dir.path}/home_fingerprint.json'));
    await store.writeHomeCastId('nest-kitchen');
    await store.writeHomeCastFriendlyName('Kitchen Nest');

    final reloaded = FileFingerprintStore(File('${dir.path}/home_fingerprint.json'));
    await reloaded.writeHashes({'hash-a', 'hash-b'});

    expect(await reloaded.readHomeCastId(), 'nest-kitchen');
    expect(await reloaded.readHomeCastIdResilient(), 'nest-kitchen');
  });

  test('readHomeCastIdResilient restores from backup file', () async {
    final dir = await Directory.systemTemp.createTemp('fp_backup_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/home_fingerprint.json';
    final store = FileFingerprintStore(File(path));
    await store.writeHomeCastId('backup-speaker');
    await store.writeHomeCastFriendlyName('Living Room');

    final corrupt = File(path);
    await corrupt.writeAsString('salt\n\nhash1\nsecret\nLiving Room\n');

    final healed = FileFingerprintStore(File(path));
    expect(await healed.readHomeCastIdResilient(), 'backup-speaker');
    expect(await healed.readHomeCastFriendlyName(), 'Living Room');
  });

  test('readSavedSpeaker recovers cast id from scan cache by name', () async {
    final dir = await Directory.systemTemp.createTemp('fp_recover_');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileFingerprintStore(File('${dir.path}/home_fingerprint.json'));
    await store.writeHomeCastFriendlyName('Kitchen Nest');
    await store.writeLastSpeakerScanJson(
      SpeakerScanResult(
        devices: [
          CastReceiver(
            deviceId: 'recovered-id',
            friendlyName: 'Kitchen Nest',
            host: InternetAddress('192.168.1.50'),
          ),
        ],
      ).toCacheJson(),
    );

    final onboarding = HomeOnboarding(
      castPlatform: FakeCastPlatform(devices: const []),
      store: store,
      lanFingerprint: LanFingerprint(
        browser: FakeMdnsBrowser(const []),
        store: store,
      ),
    );

    final saved = await onboarding.readSavedSpeaker();
    expect(saved?.deviceId, 'recovered-id');
    expect(saved?.displayName, 'Kitchen Nest');
    expect(await store.readHomeCastId(), 'recovered-id');
  });
}
