import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

final class FakeCastPlatform implements CastPlatform {
  FakeCastPlatform({
    List<CastReceiver>? devices,
    this.initialVolume = 0.4,
    this.alreadyPlayingContentId,
  }) : devices = devices ??
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
  final _events = StreamController<CastPlaybackEvent>.broadcast(sync: true);

  @override
  Stream<CastPlaybackEvent> get playbackEvents => _events.stream;

  @override
  Future<List<CastReceiver>> discover({required Duration budget}) async =>
      devices;

  @override
  Future<void> connect(CastReceiver receiver) async {
    connected = true;
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
    return CastMediaSnapshot(contentId: id, isPlaying: true);
  }

  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
  }) async {
    loadCallCount += 1;
    loadedContentId = contentId;
    loadedUrl = contentUrl;
    _events.add(CastPlaybackEvent.playing);
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

    test('saves volume before playback and restores after', () async {
      final platform = FakeCastPlatform(initialVolume: 0.3);
      final client = CastClient(platform: platform);
      await client.connectById('cast-home-1');
      await client.applyPlaybackVolume(0.8);
      expect(platform.lastSetVolume, 0.8);

      await client.restoreVolume();
      expect(platform.lastSetVolume, 0.3);
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
}
