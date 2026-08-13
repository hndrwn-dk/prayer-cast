import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/interface_selector.dart';

final class _FakeIfaces implements NetworkInterfaceSource {
  _FakeIfaces(this.ifaces);
  final List<NetworkIface> ifaces;
  @override
  Future<List<NetworkIface>> listIPv4() async => ifaces;
}

void main() {
  group('InterfaceSelector §5.2', () {
    test('picks the interface whose subnet contains the receiver', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'tun0',
            address: InternetAddress('10.8.0.2'),
            netmask: InternetAddress('255.255.255.0'),
          ),
          NetworkIface(
            name: 'wlan0',
            address: InternetAddress('192.168.1.20'),
            netmask: InternetAddress('255.255.255.0'),
          ),
        ]),
      );

      final chosen =
          await selector.selectFor(InternetAddress('192.168.1.50'));
      expect(chosen.address, '192.168.1.20');
    });

    test('off-subnet NSD claim falls back to LAN, not NO_ROUTE', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'tun0',
            address: InternetAddress('10.8.0.2'),
            netmask: InternetAddress('255.255.255.0'),
          ),
          NetworkIface(
            name: 'wlan0',
            address: InternetAddress('192.168.1.20'),
            netmask: InternetAddress('255.255.255.0'),
          ),
        ]),
      );

      final chosen =
          await selector.selectFor(InternetAddress('203.0.113.9'));
      expect(chosen.address, '192.168.1.20');
    });

    test('unspecified NSD host falls back to wlan over VPN', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'tun0',
            address: InternetAddress('10.8.0.2'),
            netmask: InternetAddress('255.255.255.0'),
          ),
          NetworkIface(
            name: 'wlan0',
            address: InternetAddress('192.168.1.20'),
            netmask: InternetAddress('255.255.255.0'),
          ),
        ]),
      );

      final chosen = await selector.selectFor(InternetAddress.anyIPv4);
      expect(chosen.address, '192.168.1.20');
    });

    test('throws NO_ROUTE_TO_RECEIVER when no subnet matches', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'tun0',
            address: InternetAddress('10.8.0.2'),
            netmask: InternetAddress('255.255.255.0'),
          ),
        ]),
      );

      expect(
        () => selector.selectFor(InternetAddress('192.168.1.50')),
        throwsA(
          isA<NoRouteToReceiverFailure>().having(
            (e) => e.outcome.code,
            'outcome',
            'FAILED_NO_ROUTE',
          ),
        ),
      );
    });

    test('sameSubnet respects netmask', () {
      expect(
        InterfaceSelector.sameSubnet(
          InternetAddress('192.168.1.10'),
          InternetAddress('255.255.255.0'),
          InternetAddress('192.168.1.200'),
        ),
        isTrue,
      );
      expect(
        InterfaceSelector.sameSubnet(
          InternetAddress('192.168.1.10'),
          InternetAddress('255.255.255.0'),
          InternetAddress('192.168.2.200'),
        ),
        isFalse,
      );
    });

    test('honors a real /16 prefix length (not assumed /24)', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'wlan0',
            address: InternetAddress('10.20.1.10'),
            netmask: netmaskFromPrefixLength(16),
          ),
        ]),
      );

      // Same /16, different third octet — would fail under assumed /24.
      final chosen =
          await selector.selectFor(InternetAddress('10.20.200.50'));
      expect(chosen.address, '10.20.1.10');
      expect(
        InterfaceSelector.sameSubnet(
          InternetAddress('10.20.1.10'),
          netmaskFromPrefixLength(24),
          InternetAddress('10.20.200.50'),
        ),
        isFalse,
      );
    });

    test('honors a real /23 prefix length across the mid-boundary', () async {
      final selector = InterfaceSelector(
        source: _FakeIfaces([
          NetworkIface(
            name: 'wlan0',
            address: InternetAddress('192.168.0.10'),
            netmask: netmaskFromPrefixLength(23),
          ),
        ]),
      );

      // 192.168.0.0/23 covers 192.168.0.0–192.168.1.255.
      final chosen =
          await selector.selectFor(InternetAddress('192.168.1.200'));
      expect(chosen.address, '192.168.0.10');
      expect(netmaskFromPrefixLength(23).address, '255.255.254.0');
    });
  });

  group('netmaskFromPrefixLength', () {
    test('maps common CIDR lengths to dotted masks', () {
      expect(netmaskFromPrefixLength(24).address, '255.255.255.0');
      expect(netmaskFromPrefixLength(16).address, '255.255.0.0');
      expect(netmaskFromPrefixLength(23).address, '255.255.254.0');
      expect(netmaskFromPrefixLength(32).address, '255.255.255.255');
      expect(netmaskFromPrefixLength(0).address, '0.0.0.0');
    });
  });
}
