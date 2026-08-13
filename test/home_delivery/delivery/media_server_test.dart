import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/delivery/media_server.dart';

void main() {
  group('MediaServer §5.1', () {
    late MediaServer server;
    late Uint8List audio;

    setUp(() {
      audio = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      server = MediaServer(
        audioBytes: audio,
        voiceId: 'makkah',
        pathToken: 'abc123def4567890',
      );
    });

    tearDown(() async {
      await server.stop();
    });

    test('serves full body with Accept-Ranges', () async {
      await server.start();
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}${server.mediaPath}'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.headers.value('content-type'), 'audio/mpeg');
      expect(response.headers.value('accept-ranges'), 'bytes');
      expect(response.headers.value('content-length'), '1000');
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(bytes, audio);
    });

    test('Range bytes=0- returns 206 with Content-Range and Content-Length',
        () async {
      await server.start();
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}${server.mediaPath}'),
      );
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(response.headers.value('content-range'), 'bytes 0-999/1000');
      expect(response.headers.value('content-length'), '1000');
      expect(response.headers.value('accept-ranges'), 'bytes');
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(bytes, audio);
    });

    test('Range bytes=100-199 returns exact slice', () async {
      await server.start();
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}${server.mediaPath}'),
      );
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=100-199');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(response.headers.value('content-range'), 'bytes 100-199/1000');
      expect(response.headers.value('content-length'), '100');
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(bytes, audio.sublist(100, 200));
    });

    test('wrong path token is 404 (no probing)', () async {
      await server.start();
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/azan/wrongtoken/makkah.mp3',
        ),
      );
      final response = await request.close();
      expect(response.statusCode, 404);
      await response.drain<void>();
    });

    test('parseRangeHeader handles bytes=0-', () {
      expect(MediaServer.parseRangeHeader('bytes=0-', 500), (0, 499));
    });
  });
}
