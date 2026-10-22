import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_audio_loader.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

class MockAdhkarAudioLoader extends Mock implements AdhkarAudioLoader {}

final class _FakePlatform implements CastPlatform {
  final receiver = CastReceiver(
    deviceId: 'cast-1',
    friendlyName: 'Kitchen',
    host: InternetAddress('192.168.1.50'),
  );
  final playback = StreamController<CastPlaybackEvent>.broadcast(sync: true);
  Object? loadError;
  Uri? loadedUrl;
  String? loadedType;
  String? loadedTitle;
  int loadCalls = 0;
  bool emitPlaying = true;
  bool fetchMedia = true;
  int connectCalls = 0;

  /// Loads that fail before the receiver is ready (dead kept-open session).
  int deadLoads = 0;

  @override
  Stream<CastPlaybackEvent> get playbackEvents => playback.stream;
  @override
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  }) async => [receiver];
  @override
  Future<void> connect(CastReceiver receiver) async {
    connectCalls++;
  }
  @override
  Future<void> warmUp() async {}
  @override
  Future<double> getVolume() async => 0.5;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<CastMediaSnapshot?> currentMedia() async => null;
  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
    String? title,
  }) async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    if (deadLoads > 0) {
      deadLoads--;
      throw CastConnectFailure('RemoteMediaClient not ready');
    }
    loadedUrl = contentUrl;
    loadedType = contentType;
    loadedTitle = title;
    if (fetchMedia) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(contentUrl);
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }
    }
    if (emitPlaying) playback.add(CastPlaybackEvent.playing);
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {}
  @override
  Future<bool> confirmSdkSighting(
    String deviceId, {
    Duration budget = const Duration(seconds: 4),
  }) async => true;
  @override
  Future<void> endSession() async {}
}

void main() {
  setUpAll(() => registerFallbackValue(AdhkarType.morning));

  late MockAdhkarAudioLoader audioLoader;
  late _FakePlatform platform;
  late CastClient castClient;
  late AdhkarDeliveryCoordinator coordinator;

  setUp(() {
    audioLoader = MockAdhkarAudioLoader();
    platform = _FakePlatform();
    castClient = CastClient(platform: platform);
    coordinator = AdhkarDeliveryCoordinator(
      audioLoader: audioLoader,
      castClient: castClient,
      resolveHost: (_) async => InternetAddress.loopbackIPv4,
    );
  });

  tearDown(() async => coordinator.dispose());

  Future<void> connect() => castClient.connectById('cast-1');

  group('AdhkarDeliveryCoordinator', () {
    test('loads audio, serves it over HTTP and casts URL', () async {
      await connect();
      when(() => audioLoader.load(AdhkarType.morning))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));

      final result = await coordinator.playAdhkar(AdhkarType.morning);

      expect(result, AdhkarDeliveryResult.success);
      verify(() => audioLoader.load(AdhkarType.morning)).called(1);
      expect(platform.loadedType, 'audio/mpeg');
      expect(platform.loadedUrl!.scheme, 'http');
      expect(platform.loadedUrl!.path, endsWith('adhkar_morning.mp3'));
    });

    test('returns speakerOffline when no Cast session', () async {
      final result = await coordinator.playAdhkar(AdhkarType.morning);

      expect(result, AdhkarDeliveryResult.speakerOffline);
      verifyNever(() => audioLoader.load(any()));
    });

    test('connects to the saved home speaker when no session is open', () async {
      when(() => audioLoader.load(AdhkarType.morning))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));
      coordinator = AdhkarDeliveryCoordinator(
        audioLoader: audioLoader,
        castClient: castClient,
        resolveHost: (_) async => InternetAddress.loopbackIPv4,
        readHomeCastId: () async => 'cast-1',
      );

      final result = await coordinator.playAdhkar(AdhkarType.morning);

      expect(result, AdhkarDeliveryResult.success);
      expect(platform.loadCalls, 1);
      expect(castClient.connected?.deviceId, 'cast-1');
      expect(platform.loadedUrl!.path, endsWith('adhkar_morning.mp3'));
    });

    test('returns audioMissing when loader returns null', () async {
      await connect();
      when(() => audioLoader.load(AdhkarType.evening))
          .thenAnswer((_) async => null);

      final result = await coordinator.playAdhkar(AdhkarType.evening);

      expect(result, AdhkarDeliveryResult.audioMissing);
      expect(platform.loadCalls, 0);
    });

    test('returns audioMissing when loader throws', () async {
      await connect();
      when(() => audioLoader.load(AdhkarType.morning))
          .thenThrow(Exception('boom'));

      expect(
        await coordinator.playAdhkar(AdhkarType.morning),
        AdhkarDeliveryResult.audioMissing,
      );
    });

    test('returns castFailed when loadMedia fails', () async {
      await connect();
      platform.loadError = Exception('Cast failed');
      when(() => audioLoader.load(AdhkarType.morning))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));

      final result = await coordinator.playAdhkar(AdhkarType.morning);

      expect(result, AdhkarDeliveryResult.castFailed);
    });

    test('reconnects once when the kept-open session is dead', () async {
      when(() => audioLoader.load(AdhkarType.morning))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));
      coordinator = AdhkarDeliveryCoordinator(
        audioLoader: audioLoader,
        castClient: castClient,
        resolveHost: (_) async => InternetAddress.loopbackIPv4,
        readHomeCastId: () async => 'cast-1',
      );
      await connect();
      platform.deadLoads = 1;

      final result = await coordinator.playAdhkar(AdhkarType.morning);

      expect(result, AdhkarDeliveryResult.success);
      expect(platform.connectCalls, 2);
      expect(platform.loadCalls, 2);
    });

    test('PLAYING without a fetch of this file is not success', () async {
      when(() => audioLoader.load(AdhkarType.evening))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));
      coordinator = AdhkarDeliveryCoordinator(
        audioLoader: audioLoader,
        castClient: castClient,
        resolveHost: (_) async => InternetAddress.loopbackIPv4,
        playbackGrace: const Duration(milliseconds: 300),
      );
      await connect();
      platform.fetchMedia = false;

      final result = await coordinator.playAdhkar(AdhkarType.evening);

      expect(result, AdhkarDeliveryResult.castFailed);
    });
  });

  group('AdhkarDeliveryCoordinator hold', () {
    test('estimates the bundled 128 kbps recitation lengths', () {
      // assets/audio/Adhkar/adhkar_morning.mpeg is 20283976 bytes, 21:07.
      final morning = AdhkarDeliveryCoordinator.estimateDuration(20283976);
      expect(morning.inSeconds, inInclusiveRange(1265, 1270));
      expect(AdhkarDeliveryCoordinator.estimateDuration(0), Duration.zero);
    });

    test('ignores an early finished and stops serving on the real one', () async {
      var now = DateTime.utc(2026, 10, 22, 6, 0);
      coordinator = AdhkarDeliveryCoordinator(
        audioLoader: audioLoader,
        castClient: castClient,
        resolveHost: (_) async => InternetAddress.loopbackIPv4,
        holdMargin: const Duration(minutes: 10),
        now: () => now,
      );
      await connect();
      when(() => audioLoader.load(AdhkarType.morning))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));
      expect(
        await coordinator.playAdhkar(AdhkarType.morning),
        AdhkarDeliveryResult.success,
      );
      expect(coordinator.lastPlaybackDuration, isNotNull);

      var held = true;
      final hold = coordinator.holdUntilFinished().then((_) => held = false);
      await Future<void>.delayed(Duration.zero);

      // Nest-style spurious finished right after load.
      now = now.add(const Duration(seconds: 5));
      platform.playback.add(CastPlaybackEvent.finished);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(held, isTrue);

      now = now.add(const Duration(minutes: 20));
      platform.playback.add(CastPlaybackEvent.finished);
      await hold;
      expect(held, isFalse);
      expect(coordinator.lastPlaybackDuration, isNull);
    });

    test('gives up when the estimated length runs out', () async {
      coordinator = AdhkarDeliveryCoordinator(
        audioLoader: audioLoader,
        castClient: castClient,
        resolveHost: (_) async => InternetAddress.loopbackIPv4,
        holdMargin: const Duration(milliseconds: 50),
      );
      await connect();
      when(() => audioLoader.load(AdhkarType.evening))
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4]));
      await coordinator.playAdhkar(AdhkarType.evening);

      await coordinator.holdUntilFinished().timeout(const Duration(seconds: 2));
      expect(coordinator.lastPlaybackDuration, isNull);
    });

    test('is a no-op when nothing was started', () async {
      await coordinator.holdUntilFinished().timeout(const Duration(seconds: 1));
    });
  });
}
