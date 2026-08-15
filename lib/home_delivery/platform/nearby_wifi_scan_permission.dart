import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Android 13+ nearby-Wi-Fi grant for Cast / NSD speaker scan.
///
/// On API 33+, [Permission.nearbyWifiDevices] is requested at scan time
/// (`neverForLocation` in the manifest). On API 32 and below this returns
/// true without prompting: scan uses `ACCESS_WIFI_STATE` and
/// `CHANGE_WIFI_MULTICAST_STATE`. This class never requests location.
final class NearbyWifiScanPermission {
  const NearbyWifiScanPermission({
    this.isAndroid,
    this.androidSdkInt,
    this.ensureAndroidGranted,
  });

  /// Test hook. Production uses [Platform.isAndroid].
  final bool? isAndroid;

  /// Test hook. When set and below 33, no runtime request is made.
  final int? androidSdkInt;

  /// Test / injection hook for the API 33+ system prompt.
  final Future<bool> Function()? ensureAndroidGranted;

  /// True when Cast / NSD scan may proceed.
  Future<bool> ensureGranted() async {
    final android = isAndroid ?? Platform.isAndroid;
    if (!android) return true;
    final sdk = androidSdkInt;
    if (sdk != null && sdk < 33) return true;
    final request = ensureAndroidGranted ?? _requestNearbyWifi;
    return request();
  }

  static Future<bool> _requestNearbyWifi() async {
    final status = await Permission.nearbyWifiDevices.status;
    if (status.isGranted) return true;
    final result = await Permission.nearbyWifiDevices.request();
    return result.isGranted;
  }
}
