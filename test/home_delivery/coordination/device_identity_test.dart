import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';

void main() {
  group('DeviceIdentity.deviceId', () {
    test('generates a UUIDv4 and persists it', () async {
      final store = MemoryDeviceIdStore();
      final identity = DeviceIdentity(
        store: store,
        uuidGenerator: const _FixedUuid('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'),
      );

      final id = await identity.deviceId();

      expect(id, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee');
      expect(await store.read(), id);
      // Second call returns the same cached/persisted value.
      expect(await identity.deviceId(), id);
    });

    test('reuses an already-persisted id and never regenerates', () async {
      final store = MemoryDeviceIdStore('11111111-2222-4333-8444-555555555555');
      var generations = 0;
      final identity = DeviceIdentity(
        store: store,
        uuidGenerator: _CountingUuid(() {
          generations += 1;
          return 'ffffffff-ffff-4fff-8fff-ffffffffffff';
        }),
      );

      expect(await identity.deviceId(), '11111111-2222-4333-8444-555555555555');
      expect(generations, 0);
    });

    test('SecureUuidV4Generator produces RFC4122 version-4 variant-1 ids', () {
      final gen = const SecureUuidV4Generator();
      final id = gen.generate();
      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(id, matches(uuidV4));
    });
  });

  group('DeviceIdentity.priority §4.4', () {
    const identity = _PriorityOnly();

    test('hub is 100', () {
      expect(
        identity.priority(
          const DeviceConditions(
            isHub: true,
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: false,
            isScreenOn: false,
            batteryPercent: 10,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        100,
      );
    });

    test('tablet plugged in with screen on is 60', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.tablet,
            isPluggedIn: true,
            isScreenOn: true,
            batteryPercent: 80,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        60,
      );
    });

    test('phone plugged in is 40', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: true,
            isScreenOn: true,
            batteryPercent: 20,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        40,
      );
    });

    test('phone on battery >50% is 25', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: false,
            isScreenOn: true,
            batteryPercent: 51,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        25,
      );
    });

    test('phone on battery ==50% is 10 (spec: <=50%)', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: false,
            isScreenOn: true,
            batteryPercent: 50,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        10,
      );
    });

    test('phone on battery <50% is 10', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: false,
            isScreenOn: false,
            batteryPercent: 15,
            batterySaverActive: false,
            clockSkewDetected: false,
          ),
        ),
        10,
      );
    });

    test('battery saver forces 0 even for a hub', () {
      expect(
        identity.priority(
          const DeviceConditions(
            isHub: true,
            formFactor: DeviceFormFactor.tablet,
            isPluggedIn: true,
            isScreenOn: true,
            batteryPercent: 100,
            batterySaverActive: true,
            clockSkewDetected: false,
          ),
        ),
        0,
      );
    });

    test('clock skew forces 0', () {
      expect(
        identity.priority(
          const DeviceConditions(
            formFactor: DeviceFormFactor.phone,
            isPluggedIn: true,
            isScreenOn: true,
            batteryPercent: 90,
            batterySaverActive: false,
            clockSkewDetected: true,
          ),
        ),
        0,
      );
    });
  });

  group('priority ordering across simulated peers §4.4', () {
    test('ranks by priority then lexicographic deviceId', () {
      final peers = [
        const PeerRank(deviceId: 'b-phone-battery', priority: 25),
        const PeerRank(deviceId: 'a-hub', priority: 100),
        const PeerRank(deviceId: 'c-phone-plugged', priority: 40),
        const PeerRank(deviceId: 'd-phone-low', priority: 10),
        // Same priority as c — lexicographically smaller id wins.
        const PeerRank(deviceId: 'a-phone-plugged', priority: 40),
        const PeerRank(deviceId: 'z-skew', priority: 0),
      ]..sort(DeviceIdentity.compareRank);

      expect(peers.map((p) => p.deviceId).toList(), [
        'a-hub',
        'a-phone-plugged',
        'c-phone-plugged',
        'b-phone-battery',
        'd-phone-low',
        'z-skew',
      ]);
    });

    test('equal priority: lower deviceId leads (deterministic across peers)', () {
      const left = PeerRank(deviceId: 'aaa-1111', priority: 40);
      const right = PeerRank(deviceId: 'bbb-2222', priority: 40);

      // Both peers independently sort the same set the same way.
      final orderOnPeerA = [left, right]..sort(DeviceIdentity.compareRank);
      final orderOnPeerB = [right, left]..sort(DeviceIdentity.compareRank);

      expect(orderOnPeerA.first.deviceId, 'aaa-1111');
      expect(orderOnPeerB.first.deviceId, 'aaa-1111');
      expect(orderOnPeerA.map((p) => p.deviceId),
          orderOnPeerB.map((p) => p.deviceId));
    });
  });
}

/// Exposes [DeviceIdentity.priority] without needing a store.
final class _PriorityOnly {
  const _PriorityOnly();

  int priority(DeviceConditions conditions) =>
      DeviceIdentity(store: MemoryDeviceIdStore()).priority(conditions);
}

final class _FixedUuid implements UuidGenerator {
  const _FixedUuid(this.value);

  final String value;

  @override
  String generate() => value;
}

final class _CountingUuid implements UuidGenerator {
  _CountingUuid(this._onGenerate);

  final String Function() _onGenerate;

  @override
  String generate() => _onGenerate();
}
