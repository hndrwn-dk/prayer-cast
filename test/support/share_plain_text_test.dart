import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/support/share_plain_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugShareText = null;
  });

  test('sharePlainText uses the test hook when set', () async {
    final shared = <String>[];
    debugShareText = (text) async => shared.add(text);
    await sharePlainText('hello');
    expect(shared, ['hello']);
  });

  test('sharePlainText invokes the native share channel', () async {
    const channel = MethodChannel('prayer_cast/share');
    Object? invoked;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invoked = call;
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await sharePlainText('invite');
    expect(invoked, isA<MethodCall>());
    final call = invoked! as MethodCall;
    expect(call.method, 'shareText');
    expect(call.arguments, 'invite');
  });
}
