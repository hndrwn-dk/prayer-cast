import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_delivery_runtime.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';

import '../delivery/cast_client_test.dart';
import '../presence/fake_mdns_browser.dart';

void main() {
  late MemoryFingerprintStore store;
  late FakeCastPlatform cast;
  late FakeMdnsBrowser browser;
  late HomeOnboarding onboarding;

  setUp(() {
    store = MemoryFingerprintStore();
    cast = FakeCastPlatform(
      devices: [
        CastReceiver(
          deviceId: 'cast-home-1',
          friendlyName: 'Kitchen Nest',
          host: InternetAddress('192.168.1.50'),
        ),
      ],
    );
    browser = FakeMdnsBrowser([
      [
        DiscoveredService(
          instanceName: 'Kitchen',
          serviceType: '_googlecast._tcp',
          txt: const {'id': 'cast-home-1'},
          host: InternetAddress('192.168.1.50'),
        ),
        DiscoveredService(
          instanceName: 'Printer',
          serviceType: '_printer._tcp',
        ),
      ],
    ]);
    onboarding = HomeOnboarding(
      castPlatform: cast,
      store: store,
      lanFingerprint: LanFingerprint(browser: browser, store: store),
    );
  });

  test('scanSpeakers returns Cast devices', () async {
    final result = await onboarding.scanSpeakers(
      budget: const Duration(milliseconds: 1),
    );
    expect(result.devices, hasLength(1));
    expect(result.devices.first.deviceId, 'cast-home-1');
  });

  test('saveHomeSpeaker persists cast id, name, and fingerprint', () async {
    expect(await onboarding.readSavedSpeaker(), isNull);

    final captured = await onboarding.saveHomeSpeaker(cast.devices.first);

    final saved = await onboarding.readSavedSpeaker();
    expect(saved?.deviceId, 'cast-home-1');
    expect(saved?.friendlyName, 'Kitchen Nest');
    expect(saved?.displayName, 'Kitchen Nest');
    expect(await store.readHomeCastId(), 'cast-home-1');
    expect(await store.readHomeCastFriendlyName(), 'Kitchen Nest');
    expect(captured.hashes, isNotEmpty);
    expect(await store.readHashes(), captured.hashes);
  });

  test('clearHomeSpeaker drops Cast target and keeps LAN extras', () async {
    await onboarding.saveHomeSpeaker(cast.devices.first);
    await store.writeElectionSecret('keep-election');
    await onboarding.writeCachedSpeakerScan(
      SpeakerScanResult(devices: [cast.devices.first]),
    );
    final hashes = await store.readHashes();
    expect(hashes, isNotEmpty);

    await onboarding.clearHomeSpeaker();

    expect(await onboarding.readSavedSpeaker(), isNull);
    expect(await store.readHomeCastId(), isEmpty);
    expect(await store.readHomeCastFriendlyName(), isEmpty);
    expect(await store.readHashes(), hashes);
    expect(await store.readElectionSecret(), 'keep-election');
    final cached = await onboarding.readCachedSpeakerScan();
    expect(cached, isNotNull);
    expect(cached!.devices.single.deviceId, 'cast-home-1');
  });

  test('cached scan reconstructs CastReceiver fields', () async {
    final original = cast.devices.first;
    await onboarding.writeCachedSpeakerScan(
      SpeakerScanResult(devices: [original]),
    );

    final cached = await onboarding.readCachedSpeakerScan();
    expect(cached, isNotNull);
    expect(cached!.devices, hasLength(1));
    final rebuilt = cached.devices.first;
    expect(rebuilt.deviceId, original.deviceId);
    expect(rebuilt.friendlyName, original.friendlyName);
    expect(rebuilt.host.address, original.host.address);
  });

  test('empty scan is a cache hit so launch does not rescan', () async {
    await onboarding.writeCachedSpeakerScan(
      const SpeakerScanResult(devices: []),
    );
    final cached = await onboarding.readCachedSpeakerScan();
    expect(cached, isNotNull);
    expect(cached!.devices, isEmpty);
  });

  test('corrupt cache is treated as a miss', () async {
    await store.writeLastSpeakerScanJson('{not-json');
    expect(await onboarding.readCachedSpeakerScan(), isNull);
  });

  test(
    'FileFingerprintStore keeps speaker scan when writing cast id',
    () async {
      final dir = await Directory.systemTemp.createTemp('speaker_scan_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/home_fingerprint.json';
      final store = FileFingerprintStore(File(path));
      await store.writeLastSpeakerScanJson(
        SpeakerScanResult(
          devices: [
            CastReceiver(
              deviceId: 'nest-1',
              friendlyName: 'Kitchen',
              host: InternetAddress('192.168.1.40'),
            ),
          ],
        ).toCacheJson(),
      );
      await store.writeHomeCastId('other-id');

      final reloaded = FileFingerprintStore(File(path));
      expect(await reloaded.readHomeCastId(), 'other-id');
      final parsed = SpeakerScanResult.fromCacheJson(
        (await reloaded.readLastSpeakerScanJson())!,
      );
      expect(parsed, isNotNull);
      expect(parsed!.devices.single.deviceId, 'nest-1');
      expect(parsed.devices.single.host.address, '192.168.1.40');
    },
  );
}
