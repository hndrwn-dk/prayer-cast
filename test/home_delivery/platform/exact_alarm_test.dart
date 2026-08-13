import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('prayer_cast/exact_alarm');
  const eventChannel = EventChannel('prayer_cast/exact_alarm_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'scheduleNext':
        case 'cancel':
        case 'requestExactAlarmPermission':
        case 'stopForegroundService':
          return null;
        case 'canScheduleExactAlarms':
          return true;
        case 'getScheduled':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  test('scheduleNext invokes MethodChannel with epoch, prayer, and voiceId',
      () async {
    final alarm = ExactAlarm();
    await alarm.scheduleNext(
      epochMs: 1_700_000_000_000,
      prayer: 'maghrib',
      voiceId: 'makkah',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'scheduleNext');
    expect(calls.single.arguments, {
      'epochMs': 1_700_000_000_000,
      'prayer': 'maghrib',
      'voiceId': 'makkah',
    });
  });

  test('readScheduled maps getScheduled payload', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      if (call.method == 'getScheduled') {
        return {
          'epochMs': 1_700_000_000_000,
          'prayer': 'isha-dryrun',
          'voiceId': 'makkah',
        };
      }
      return null;
    });
    final alarm = ExactAlarm();
    final scheduled = await alarm.readScheduled();
    expect(calls.single.method, 'getScheduled');
    expect(scheduled, isNotNull);
    expect(scheduled!.prayer, 'isha-dryrun');
    expect(scheduled.epochMs, 1_700_000_000_000);
    expect(scheduled.voiceId, 'makkah');
  });

  test('canScheduleExactAlarms returns platform bool', () async {
    final alarm = ExactAlarm();
    expect(await alarm.canScheduleExactAlarms(), isTrue);
  });

  test('no_permission maps to ExactAlarmFailure with FAILED_ALARM_MISSED',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'no_permission', message: 'denied');
    });

    final alarm = ExactAlarm();
    expect(
      () => alarm.scheduleNext(epochMs: 1, prayer: 'fajr', voiceId: 'makkah'),
      throwsA(
        isA<ExactAlarmFailure>()
            .having((e) => e.outcome, 'outcome', Outcome.failedAlarmMissed)
            .having(
              (e) => e.message,
              'message',
              contains('SCHEDULE_EXACT_ALARM'),
            ),
      ),
    );
  });

  test('onFired parses EventChannel payload including voiceId', () async {
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? args, MockStreamHandlerEventSink sink) {
          sink.success(<String, Object?>{
            'prayer': 'isha',
            'scheduledEpochMs': 1000,
            'firedAtMs': 1000 + 61 * 1000,
            'voiceId': 'madinah',
          });
        },
      ),
    );

    final alarm = ExactAlarm();
    final event = await alarm.onFired.first;
    expect(event.prayer, 'isha');
    expect(event.scheduledEpochMs, 1000);
    expect(event.firedAtMs, 1000 + 61 * 1000);
    expect(event.voiceId, 'madinah');
    expect(event.isMissed, isTrue);
  });

  test('onFired isMissed false when within 60s', () async {
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? args, MockStreamHandlerEventSink sink) {
          sink.success(<String, Object?>{
            'prayer': 'dhuhr',
            'scheduledEpochMs': 5000,
            'firedAtMs': 5000 + 30 * 1000,
            'voiceId': 'makkah',
          });
        },
      ),
    );

    final event = await ExactAlarm().onFired.first;
    expect(event.isMissed, isFalse);
  });

  test(
    'MissingPluginException does not abort canSchedule / scheduleNext',
    () async {
      // Simulate iOS: no ExactAlarmPlugin registered for the channel.
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw MissingPluginException('No implementation for ${call.method}');
      });

      final alarm = ExactAlarm();
      expect(await alarm.canScheduleExactAlarms(), isTrue);
      await expectLater(
        alarm.scheduleNext(
          epochMs: 1,
          prayer: 'fajr',
          voiceId: 'makkah',
        ),
        completes,
      );
      await expectLater(alarm.cancel(), completes);
      await expectLater(alarm.requestExactAlarmPermission(), completes);
      await expectLater(alarm.stopForegroundService(), completes);
    },
  );
}
