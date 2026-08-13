import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

final class FakeCastPlatform implements CastPlatform {
  FakeCastPlatform({
    List<CastReceiver>? devices,
    this.initialVolume = 0.4,
    this.alreadyPlayingContentId,
    this.emitPlayingOnLoad = true,
    this.emitPlayingOnCall,
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

  double? lastSetVolume;
  String? loadedContentId;
  Uri? loadedUrl;
  int loadCallCount = 0;
  bool connected = false;
  bool sessionEnded = false;
  Object? discoverError;
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
    connected = true;
  }

  @override
  Future<void> warmUp() async {}

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
    return CastMediaSnapshot(contentId: id, isPlaying: true);
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
  group('CastClient §5.3 / §4.8', () {
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
