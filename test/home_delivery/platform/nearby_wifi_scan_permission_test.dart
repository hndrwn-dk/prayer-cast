import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/nearby_wifi_scan_permission.dart';

void main() {
  test('non-Android scan does not request nearby Wi-Fi', () async {
    var requested = false;
    final gate = NearbyWifiScanPermission(
      isAndroid: false,
      androidSdkInt: 34,
      ensureAndroidGranted: () async {
        requested = true;
        return false;
      },
    );
    expect(await gate.ensureGranted(), isTrue);
    expect(requested, isFalse);
  });

  test('API 32 and below does not request nearby Wi-Fi or location', () async {
    var requested = false;
    final gate = NearbyWifiScanPermission(
      isAndroid: true,
      androidSdkInt: 32,
      ensureAndroidGranted: () async {
        requested = true;
        return false;
      },
    );
    expect(await gate.ensureGranted(), isTrue);
    expect(requested, isFalse);
  });

  test('API 33+ requests nearby Wi-Fi and respects denial', () async {
    final gate = NearbyWifiScanPermission(
      isAndroid: true,
      androidSdkInt: 33,
      ensureAndroidGranted: () async => false,
    );
    expect(await gate.ensureGranted(), isFalse);
  });

  test('API 33+ granted allows scan', () async {
    final gate = NearbyWifiScanPermission(
      isAndroid: true,
      androidSdkInt: 33,
      ensureAndroidGranted: () async => true,
    );
    expect(await gate.ensureGranted(), isTrue);
  });
}
