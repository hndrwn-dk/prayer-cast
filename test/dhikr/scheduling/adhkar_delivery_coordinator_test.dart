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

  @override
  Stream<CastPlaybackEvent> get playbackEvents => playback.stream;
  @override
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  }) async => [receiver];
  @override
  Future<void> connect(CastReceiver receiver) async {}
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
    loadedUrl = contentUrl;
    loadedType = contentType;
    loadedTitle = title;
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
  });
}
