import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

final class FakeCastPlatform implements CastPlatform {
  FakeCastPlatform({
    List<CastReceiver>? devices,
    this.initialVolume = 0.4,
    this.alreadyPlayingContentId,
    this.alreadyPlayingTitle,
    this.emitPlayingOnLoad = true,
    this.emitPlayingOnCall,
    this.connectFailuresBeforeSuccess = 0,
  }) : devices =
           devices ??
           [
             CastReceiver(
               deviceId: 'cast-home-1',
               friendlyName: 'Kitchen',
               host: InternetAddress('192.168.1.50'),
             ),
           ];

  final List<CastReceiver> devices;
  double initialVolume;
  String? alreadyPlayingContentId;
  String? alreadyPlayingTitle;

  double? lastSetVolume;
  String? loadedContentId;
  Uri? loadedUrl;
  int loadCallCount = 0;
  bool connected = false;
  bool sessionEnded = false;
  Object? discoverError;
  Object? connectError;
  /// Fail connect this many times, then succeed (Fajr vanished → retry).
  int connectFailuresBeforeSuccess = 0;
  int connectCalls = 0;
  int warmUpCalls = 0;
  bool emitPlayingOnLoad;
  /// If set, only the Nth loadMedia call (1-based) emits PLAYING.
  int? emitPlayingOnCall;
  Completer<void>? readyGate;
  final _events = StreamController<CastPlaybackEvent>.broadcast(sync: true);

  int discoverCalls = 0;

  @override
  Stream<CastPlaybackEvent> get playbackEvents => _events.stream;

  @override
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  }) async {
    discoverCalls += 1;
    final error = discoverError;
    if (error != null) throw error;
    return devices;
  }

  @override
  Future<void> connect(CastReceiver receiver) async {
    connectCalls += 1;
    final error = connectError;
    if (error != null) throw error;
    if (connectCalls <= connectFailuresBeforeSuccess) {
      throw CastConnectFailure(
        'Device ${receiver.deviceId} vanished before connect',
      );
    }
    connected = true;
  }

  @override
  Future<void> warmUp() async {
    warmUpCalls += 1;
  }

  @override
  Future<double> getVolume() async => initialVolume;

  @override
  Future<void> setVolume(double volume) async {
    lastSetVolume = volume;
    initialVolume = volume;
  }

  @override
  Future<CastMediaSnapshot?> currentMedia() async {
    final id = alreadyPlayingContentId;
    if (id == null) return null;
    return CastMediaSnapshot(
      contentId: id,
      title: alreadyPlayingTitle,
      isPlaying: true,
    );
  }

  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
    String? title,
  }) async {
    loadCallCount += 1;
    loadedContentId = contentId;
    loadedUrl = contentUrl;
    final nth = emitPlayingOnCall;
    final shouldEmit = emitPlayingOnLoad &&
        (nth == null || loadCallCount == nth);
    if (shouldEmit) {
      _events.add(CastPlaybackEvent.playing);
    }
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final gate = readyGate;
    if (gate != null) {
      await gate.future.timeout(timeout);
    }
  }

  @override
  Future<void> endSession() async {
    sessionEnded = true;
    connected = false;
  }

  void finishPlayback() => _events.add(CastPlaybackEvent.finished);
}

void main() {
  group('CastDiscoveryPolicy', () {
    test('early-exit requires Cast SDK sighting, not NSD-only', () {
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: 'cast-home-1',
          sdkDeviceIds: const [],
        ),
        isFalse,
      );
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: 'cast-home-1',
          sdkDeviceIds: const ['other'],
        ),
        isFalse,
      );
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: 'cast-home-1',
          sdkDeviceIds: const ['cast-home-1'],
        ),
        isTrue,
      );
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: null,
          sdkDeviceIds: const ['cast-home-1'],
        ),
        isFalse,
      );
    });
  });

  group('CastSdkDeviceMap', () {
    test('snapshot sighting is enough without a later stream event', () {
      final sdkDevices = <String, String>{};
      CastSdkDeviceMap.put(
        sdkDevices,
        deviceId: 'cast-home-1',
        friendlyName: 'Family room speaker',
      );
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: 'cast-home-1',
          sdkDeviceIds: sdkDevices.keys,
        ),
        isTrue,
      );
    });

    test('empty id is ignored', () {
      final sdkDevices = <String, String>{};
      CastSdkDeviceMap.put(
        sdkDevices,
        deviceId: '',
        friendlyName: 'ignored',
      );
      expect(sdkDevices, isEmpty);
    });

    test('scheduled discover may keep an NSD-only match for connect wait', () {
      // Policy still requires SDK for early-exit; NSD-only is a last-resort
      // list entry so connectById can wait on MediaRouter instead of
      // FAILED_NO_TARGET while Home already saw the speaker.
      expect(
        CastDiscoveryPolicy.sdkConfirmedMatch(
          matchId: 'cast-home-1',
          sdkDeviceIds: const [],
        ),
        isFalse,
      );
    });
  });

  group('CastClient §5.3 / §4.8', () {
    test('retries connectById once after vanished before connect', () async {
      final platform = FakeCastPlatform(
        connectFailuresBeforeSuccess: 1,
      );
      final client = CastClient(platform: platform);
      final receiver = await client.connectById('cast-home-1');
      expect(receiver.deviceId, 'cast-home-1');
      expect(platform.connectCalls, 2);
      expect(platform.warmUpCalls, 1);
      expect(platform.discoverCalls, 2);
      expect(platform.connected, isTrue);
    });

    test('rethrows after two vanished connect failures', () async {
      final platform = FakeCastPlatform(
        connectFailuresBeforeSuccess: 99,
      );
      final client = CastClient(platform: platform);
      await expectLater(
        () => client.connectById('cast-home-1'),
        throwsA(
          isA<CastConnectFailure>().having(
            (e) => e.toString(),
            'message',
            contains('vanished before connect'),
          ),
        ),
      );
      expect(platform.connectCalls, 2);
      expect(platform.warmUpCalls, 1);
    });

    test('matches by device id not friendly name', () async {
      final platform = FakeCastPlatform(
        devices: [
          CastReceiver(
            deviceId: 'id-a',
            friendlyName: 'Renamed Speaker',
            host: InternetAddress('192.168.1.10'),
          ),
        ],
      );
      final client = CastClient(platform: platform);
      final receiver = await client.connectById('id-a');
      expect(receiver.friendlyName, 'Renamed Speaker');
      expect(platform.connected, isTrue);
    });

    test('missing id → FAILED_NO_TARGET', () async {
      final client = CastClient(platform: FakeCastPlatform(devices: []));
      expect(
        () => client.connectById('missing'),
        throwsA(isA<CastTargetMissingFailure>()),
      );
    });

    test('keeps audible speaker volume instead of boosting', () async {
      final platform = FakeCastPlatform(initialVolume: 0.18);
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      await client.applyPlaybackVolume(0.7);
      expect(platform.lastSetVolume, isNull);
      expect(platform.initialVolume, 0.18);

      await client.restoreVolume();
      expect(platform.initialVolume, 0.18);
    });

    test('saves volume before playback and restores after when muted',
        () async {
      final platform = FakeCastPlatform(initialVolume: 0.0);
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      await client.applyPlaybackVolume(0.8);
      expect(platform.lastSetVolume, 0.8);

      await client.restoreVolume();
      expect(platform.lastSetVolume, 0.8);
    });

    test('does not restore volume 0 after setting playback level', () async {
      // Isha 2026-08-13: saved 0.0, set 0.7, restored 0 — blip then mute.
      final platform = FakeCastPlatform(initialVolume: 0.0);
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      await client.applyPlaybackVolume(0.7);
      expect(platform.lastSetVolume, 0.7);

      await client.restoreVolume();
      expect(platform.lastSetVolume, 0.7);
    });

    test('session connected is not enough to load — media client must be ready',
        () {
      expect(
        CastLoadReadiness.isLoadable(
          sessionConnected: true,
          mediaClientReady: false,
        ),
        isFalse,
      );
      expect(
        CastLoadReadiness.isLoadable(
          sessionConnected: true,
          mediaClientReady: true,
        ),
        isTrue,
      );
    });

    test('loadAdzan does not call loadMedia until media client is ready',
        () async {
      final platform = FakeCastPlatform();
      final gate = Completer<void>();
      platform.readyGate = gate;
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');

      var loaded = false;
      final load = client.loadAdzan(
        contentId: 'adzan:test:makkah',
        contentUrl: Uri.parse('http://192.168.1.20/azan/x/makkah.mp3'),
      )..then((_) => loaded = true);

      await Future<void>.delayed(Duration.zero);
      expect(loaded, isFalse);
      expect(platform.loadCallCount, 0);

      gate.complete();
      await load;
      expect(loaded, isTrue);
      expect(platform.loadCallCount, 1);
    });

    test('duplicate contentId → SUPPRESSED_ALREADY_PLAYING', () async {
      const contentId = 'adzan:session:makkah';
      final platform = FakeCastPlatform(alreadyPlayingContentId: contentId);
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      expect(
        () => client.assertNotAlreadyPlaying(contentId),
        throwsA(isA<CastAlreadyPlayingFailure>()),
      );
    });

    test('§4.8 matches metadata title when contentId is the HTTP URL', () async {
      const logical = 'adzan:session:makkah';
      final platform = FakeCastPlatform(
        alreadyPlayingContentId:
            'http://192.168.1.20:8080/azan/token/makkah.mp3',
        alreadyPlayingTitle: logical,
      );
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      expect(
        () => client.assertNotAlreadyPlaying(logical),
        throwsA(isA<CastAlreadyPlayingFailure>()),
      );
    });
  });

  group('CastSdkDeviceWait', () {
    test('waits until the SDK lists the saved device', () async {
      var polls = 0;
      final match = await CastSdkDeviceWait.untilPresent<String>(
        deviceId: 'cast-home-1',
        devices: () {
          polls += 1;
          return polls >= 3 ? ['cast-home-1'] : const <String>[];
        },
        idOf: (id) => id,
        delay: (_) async {},
      );
      expect(match, 'cast-home-1');
      expect(polls, 3);
    });

    test('throws vanished when the SDK never lists the device', () async {
      var t = DateTime.utc(2026, 8, 14, 5, 43);
      await expectLater(
        () => CastSdkDeviceWait.untilPresent<String>(
          deviceId: 'e42afc3cd44438e2ded41c07eb515fd1',
          devices: () => const [],
          idOf: (id) => id,
          timeout: const Duration(seconds: 1),
          now: () => t,
          delay: (_) async {
            t = t.add(const Duration(seconds: 1));
          },
        ),
        throwsA(
          isA<CastConnectFailure>().having(
            (e) => e.toString(),
            'message',
            contains('vanished before connect'),
          ),
        ),
      );
    });

    test('refreshes discovery while waiting for MediaRouter', () async {
      var t = DateTime.utc(2026, 9, 5, 5, 42);
      var refreshes = 0;
      var polls = 0;
      final match = await CastSdkDeviceWait.untilPresent<String>(
        deviceId: '7ef7209172e05e347c46a3895131452d',
        devices: () {
          polls += 1;
          return refreshes >= 2
              ? ['7ef7209172e05e347c46a3895131452d']
              : const <String>[];
        },
        idOf: (id) => id,
        timeout: const Duration(seconds: 10),
        now: () => t,
        delay: (_) async {
          t = t.add(const Duration(seconds: 1));
        },
        refresh: () async {
          refreshes += 1;
        },
      );
      expect(match, '7ef7209172e05e347c46a3895131452d');
      expect(refreshes, greaterThanOrEqualTo(2));
      expect(polls, greaterThan(1));
    });
  });

  group('CastSessionConnect retry', () {
    test('retries startSession once when session never connected', () async {
      var starts = 0;
      var waits = 0;
      var connected = false;
      await CastSessionConnect.run(
        startSession: () async {
          starts += 1;
          return true;
        },
        waitUntilReady: (timeout) async {
          waits += 1;
          if (waits == 1) {
            throw CastConnectFailure(
              'Cast session not connected within ${timeout.inSeconds}s',
            );
          }
          connected = true;
        },
        sessionConnected: () async => connected,
      );
      expect(starts, 2);
      expect(waits, 2);
    });

    test('does not end or restart a session that already connected', () async {
      var starts = 0;
      var waits = 0;
      await CastSessionConnect.run(
        startSession: () async {
          starts += 1;
          return true;
        },
        waitUntilReady: (timeout) async {
          waits += 1;
          if (waits == 1) {
            throw CastConnectFailure(
              'Cast RemoteMediaClient not ready within ${timeout.inSeconds}s',
            );
          }
        },
        sessionConnected: () async => true,
      );
      expect(starts, 1);
      expect(waits, 2);
    });

    test('FAILED_CAST_CONNECT after retry exhausted', () async {
      var starts = 0;
      await expectLater(
        CastSessionConnect.run(
          startSession: () async {
            starts += 1;
            return true;
          },
          waitUntilReady: (timeout) async {
            throw CastConnectFailure(
              'Cast session not connected within ${timeout.inSeconds}s',
            );
          },
          sessionConnected: () async => false,
        ),
        throwsA(isA<CastConnectFailure>()),
      );
      expect(starts, 2);
    });

    test('second wait is longer than the first (Dynamite / group connect)',
        () async {
      final waits = <Duration>[];
      await CastSessionConnect.run(
        startSession: () async => true,
        waitUntilReady: (timeout) async {
          waits.add(timeout);
          if (waits.length == 1) {
            throw CastConnectFailure(
              'Cast session not connected within ${timeout.inSeconds}s',
            );
          }
        },
        sessionConnected: () async => false,
      );
      expect(waits, [
        CastSessionConnect.firstWait,
        CastSessionConnect.retryWait,
      ]);
      expect(
        CastSessionConnect.retryWait,
        greaterThan(CastSessionConnect.firstWait),
      );
    });
  });
}
