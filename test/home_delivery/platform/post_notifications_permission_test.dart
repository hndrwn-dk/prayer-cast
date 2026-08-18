import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/post_notifications_permission.dart';

void main() {
  test('non-Android does not request notifications', () async {
    var requested = false;
    final gate = PostNotificationsPermission(
      isAndroid: false,
      androidSdkInt: 34,
      readGranted: () async => false,
      requestGrant: () async {
        requested = true;
        return false;
      },
    );
    expect(await gate.isGranted(), isTrue);
    expect(await gate.request(), isTrue);
    expect(requested, isFalse);
  });

  test('API 32 and below does not request POST_NOTIFICATIONS', () async {
    var requested = false;
    final gate = PostNotificationsPermission(
      isAndroid: true,
      androidSdkInt: 32,
      readGranted: () async => false,
      requestGrant: () async {
        requested = true;
        return false;
      },
    );
    expect(await gate.isGranted(), isTrue);
    expect(await gate.request(), isTrue);
    expect(requested, isFalse);
  });

  test('API 33+ reports denial and request result', () async {
    final gate = PostNotificationsPermission(
      isAndroid: true,
      androidSdkInt: 33,
      readGranted: () async => false,
      requestGrant: () async => false,
    );
    expect(await gate.isGranted(), isFalse);
    expect(await gate.request(), isFalse);
  });

  test('API 33+ granted skips asking again', () async {
    var requested = false;
    final gate = PostNotificationsPermission(
      isAndroid: true,
      androidSdkInt: 33,
      readGranted: () async => true,
      requestGrant: () async {
        requested = true;
        return true;
      },
    );
    expect(await gate.isGranted(), isTrue);
    expect(requested, isFalse);
  });

  test('non-Android openSettings does not open the system page', () async {
    var opened = false;
    final gate = PostNotificationsPermission(
      isAndroid: false,
      androidSdkInt: 34,
      openSettingsPage: () async {
        opened = true;
        return true;
      },
    );
    expect(await gate.openSettings(), isTrue);
    expect(opened, isFalse);
  });
}
