import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordination/device_identity.dart';
import 'package:prayer_cast/home_delivery/platform/device_conditions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('prayer_cast/device_conditions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('maps platform payload; forces isHub=false and clockSkewDetected=false',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'current');
      return <String, Object?>{
        'formFactor': 'tablet',
        'isPluggedIn': true,
        'isScreenOn': false,
        'batteryPercent': 88,
        'batterySaverActive': true,
        'clockSkewDetected': true, // ignored — Election detects live
        'isHub': true, // ignored — hub is build config (§9)
      };
    });

    final conditions = await MethodChannelDeviceConditions().current();
    expect(conditions.formFactor, DeviceFormFactor.tablet);
    expect(conditions.isPluggedIn, isTrue);
    expect(conditions.isScreenOn, isFalse);
    expect(conditions.batteryPercent, 88);
    expect(conditions.batterySaverActive, isTrue);
    expect(conditions.clockSkewDetected, isFalse);
    expect(conditions.isHub, isFalse);
  });
}
