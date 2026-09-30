import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordination/peer_registry.dart';

void main() {
  group('PeerUnicastAddress.resolve', () {
    test('prefers non-loopback IPv4 when IPv6 is listed first', () {
      final v6 = InternetAddress('fe80::1');
      final v4 = InternetAddress('192.168.1.42');
      final resolved = PeerUnicastAddress.resolve(
        addresses: [v6, v4],
        host: 'ignored.local',
      );
      expect(resolved, same(v4));
      expect(resolved.type, InternetAddressType.IPv4);
    });

    test('skips loopback IPv4 in favor of LAN IPv4', () {
      final loop = InternetAddress.loopbackIPv4;
      final lan = InternetAddress('10.0.0.8');
      final resolved = PeerUnicastAddress.resolve(
        addresses: [loop, lan],
        host: 'ignored.local',
      );
      expect(resolved, same(lan));
    });

    test('falls back to first address when only IPv6 is present', () {
      final v6 = InternetAddress('2001:db8::1');
      final resolved = PeerUnicastAddress.resolve(
        addresses: [v6],
        host: 'ignored.local',
      );
      expect(resolved, same(v6));
    });

    test('parses host string when addresses list is empty', () {
      final resolved = PeerUnicastAddress.resolve(
        addresses: const [],
        host: '192.168.0.9',
      );
      expect(resolved.address, '192.168.0.9');
      expect(resolved.type, InternetAddressType.IPv4);
    });

    test('parses host string when addresses is null', () {
      final resolved = PeerUnicastAddress.resolve(
        addresses: null,
        host: '192.168.0.10',
      );
      expect(resolved.address, '192.168.0.10');
    });

    test('falls back to non-loopback IPv6 instead of loopback IPv4', () {
      final loop = InternetAddress.loopbackIPv4;
      final v6 = InternetAddress('2001:db8::1');
      final resolved = PeerUnicastAddress.resolve(
        addresses: [loop, v6],
        host: 'ignored.local',
      );
      expect(resolved, same(v6));
    });
  });

  group('PeerUnicastAddress.keepWorkingUnicast', () {
    test('keeps learned LAN IPv4 when advertised address is loopback', () {
      final learned = InternetAddress('192.168.1.42');
      final advertised = InternetAddress.loopbackIPv4;
      expect(
        PeerUnicastAddress.keepWorkingUnicast(
          learned: learned,
          advertised: advertised,
        ),
        same(learned),
      );
    });

    test('keeps learned LAN IPv4 when advertised address is IPv6', () {
      final learned = InternetAddress('10.0.0.8');
      final advertised = InternetAddress('fe80::1');
      expect(
        PeerUnicastAddress.keepWorkingUnicast(
          learned: learned,
          advertised: advertised,
        ),
        same(learned),
      );
    });

    test('takes advertised LAN IPv4 when the peer moved', () {
      final learned = InternetAddress('192.168.1.42');
      final advertised = InternetAddress('192.168.1.99');
      expect(
        PeerUnicastAddress.keepWorkingUnicast(
          learned: learned,
          advertised: advertised,
        ),
        same(advertised),
      );
    });
  });
}
