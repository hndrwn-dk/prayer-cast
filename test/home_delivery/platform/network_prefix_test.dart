import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/network_prefix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('prayer_cast/network_prefix');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('listPrefixLengths maps platform payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listIPv4Prefixes');
      return [
        {
          'name': 'wlan0',
          'address': '192.168.1.20',
          'prefixLength': 23,
        },
        {
          'name': 'tun0',
          'address': '10.8.0.2',
          'prefixLength': 24,
        },
      ];
    });

    final lookup = MethodChannelNetworkPrefix();
    final prefixes = await lookup.listPrefixLengths();
    expect(prefixes, hasLength(2));
    expect(prefixes.first.address, '192.168.1.20');
    expect(prefixes.first.prefixLength, 23);
    expect(prefixes.last.name, 'tun0');
  });

  test('listPrefixLengths rethrows PlatformException after logging', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable', message: 'no ifaddrs');
    });

    final lookup = MethodChannelNetworkPrefix();
    expect(
      () => lookup.listPrefixLengths(),
      throwsA(isA<PlatformException>()),
    );
  });
}
