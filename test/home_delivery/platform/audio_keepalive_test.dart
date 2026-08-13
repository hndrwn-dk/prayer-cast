import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/platform/audio_keepalive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('prayer_cast/audio_keepalive');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'start':
        case 'stop':
          return null;
        case 'isActive':
          return calls.any((c) => c.method == 'start') &&
              !calls.any((c) => c.method == 'stop');
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('start/stop/isActive bridge MethodChannel', () async {
    final keepalive = AudioKeepalive();
    await keepalive.start();
    expect(await keepalive.isActive(), isTrue);
    await keepalive.stop();

    expect(calls.map((c) => c.method), ['start', 'isActive', 'stop']);
  });

  test('start PlatformException becomes AudioKeepaliveFailure', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'keepalive_start_failed', message: 'boom');
    });

    expect(
      () => AudioKeepalive().start(),
      throwsA(
        isA<AudioKeepaliveFailure>().having(
          (e) => e.message,
          'message',
          contains('boom'),
        ),
      ),
    );
  });
}
