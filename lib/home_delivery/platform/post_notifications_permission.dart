import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Android 13+ [POST_NOTIFICATIONS] grant so the adzan FGS shade is visible.
///
/// On API 32 and below this returns true without prompting. Denial does not
/// block scheduling; the system simply drops the notification.
final class PostNotificationsPermission {
  const PostNotificationsPermission({
    this.isAndroid,
    this.androidSdkInt,
    this.readGranted,
    this.requestGrant,
  });

  /// Test hook. Production uses [Platform.isAndroid].
  final bool? isAndroid;

  /// Test hook. When set and below 33, no runtime request is made.
  final int? androidSdkInt;

  /// Test / injection hook for the current grant.
  final Future<bool> Function()? readGranted;

  /// Test / injection hook for the API 33+ system prompt.
  final Future<bool> Function()? requestGrant;

  Future<bool> isGranted() async {
    final android = isAndroid ?? Platform.isAndroid;
    if (!android) return true;
    final sdk = androidSdkInt;
    if (sdk != null && sdk < 33) return true;
    final read = readGranted ?? _statusGranted;
    return read();
  }

  Future<bool> request() async {
    final android = isAndroid ?? Platform.isAndroid;
    if (!android) return true;
    final sdk = androidSdkInt;
    if (sdk != null && sdk < 33) return true;
    final ask = requestGrant ?? _requestNotification;
    return ask();
  }

  static Future<bool> _statusGranted() async {
    return Permission.notification.isGranted;
  }

  static Future<bool> _requestNotification() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
