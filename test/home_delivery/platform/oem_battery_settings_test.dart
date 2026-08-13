import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/oem_battery_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('prayer_cast/oem_battery');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'canOpen':
          return true;
        case 'open':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('canOpen / open bridge MethodChannel', () async {
    final settings = OemBatterySettings();
    expect(await settings.canOpen(), isTrue);
    expect(await settings.open(), isTrue);
  });

  test('shouldShowOemBatteryNudge after 2 misses', () {
    expect(shouldShowOemBatteryNudge(0), isFalse);
    expect(shouldShowOemBatteryNudge(1), isFalse);
    expect(shouldShowOemBatteryNudge(2), isTrue);
    expect(shouldShowOemBatteryNudge(5), isTrue);
  });
}
