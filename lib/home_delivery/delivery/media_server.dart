import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../common/logger.dart';

/// Local shelf HTTP server for Cast media fetch (spec §5.1).
///
/// WHY: Offline-first — audio is bundled and served from the device. Cast
/// receivers require correct `206 Partial Content` with `Content-Range` and
/// `Content-Length`. A per-session random path token prevents LAN probing.
final class MediaServer {
  MediaServer({
    required this.audioBytes,
    required this.voiceId,
    this.contentType = 'audio/mpeg',
    this.fileExtension = 'mp3',
    HomeDeliveryLogger logger = const SilentLogger(),
    String? pathToken,
  })  : pathToken = pathToken ?? _randomToken(),
        _logger = logger;

  /// Raw audio bytes (bundled asset, loaded by the app shell).
  final Uint8List audioBytes;

  /// Voice identifier used in the URL path (`{voiceId}.{ext}`).
  final String voiceId;

  /// MIME type advertised to Cast (`audio/mpeg` or `audio/wav`).
  final String contentType;

  /// File extension in the media path.
  final String fileExtension;

  /// Per-session path token (§5.1) — random, not guessable on the LAN.
  final String pathToken;

  final HomeDeliveryLogger _logger;

  HttpServer? _server;
  Completer<void>? _stopped;
  int _hitCount = 0;

  /// Ephemeral port once [start] has completed.
  int? get port => _server?.port;

  /// Whether the server is currently accepting connections.
  bool get isRunning => _server != null;

  /// Successful GET/HEAD hits on the media path (Cast fetch probe).
  int get hitCount => _hitCount;

  /// Public URL path for this session (no host).
  String get mediaPath => '/azan/$pathToken/$voiceId.$fileExtension';

  /// Full URL advertised to the Cast receiver.
  Uri mediaUri(InternetAddress host) => Uri(
        scheme: 'http',
        host: host.address,
        port: port,
        path: mediaPath,
      );

  /// Start listening on `0.0.0.0` with an ephemeral port.
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await shelf_io.serve(
        _handler,
        InternetAddress.anyIPv4,
        0,
      );
      _stopped = Completer<void>();
      _logger.info(
        'MediaServer listening on port ${_server!.port} path=$mediaPath',
        tag: 'MediaServer',
      );
    } on SocketException catch (e, st) {
      _logger.error(
        'MediaServer bind failed',
        tag: 'MediaServer',
        error: e,
        stackTrace: st,
      );
      throw MediaServerFailure('Bind failed: $e', cause: e);
    }
  }

  /// Stop the server. Idempotent.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await server.close(force: true);
    final stopped = _stopped;
    if (stopped != null && !stopped.isCompleted) {
      stopped.complete();
    }
    _logger.info('MediaServer stopped', tag: 'MediaServer');
  }

  /// Completes when [stop] is called (for lifetime supervision).
  Future<void> get done => _stopped?.future ?? Future<void>.value();

  FutureOr<Response> _handler(Request request) {
    final method = request.method;
    // Cast receivers often probe with HEAD before GET. Rejecting HEAD with
    // 405 is a common cause of "loadMedia OK, speaker silent".
    if (method != 'GET' && method != 'HEAD') {
      return Response(405, body: 'Method Not Allowed');
    }

    // shelf exposes path without a leading slash.
    final path = '/${request.url.path}';
    if (path != mediaPath) {
      _logger.warn(
        'MediaServer ${method} miss path=$path',
        tag: 'MediaServer',
      );
      return Response.notFound('Not Found');
    }

    final total = audioBytes.length;
    final rangeHeader = request.headers['range'];
    final isHead = method == 'HEAD';

    if (rangeHeader == null || rangeHeader.isEmpty) {
      _hitCount++;
      _logger.info(
        'MediaServer $method full bytes=$total hit=$_hitCount',
        tag: 'MediaServer',
      );
      return Response(
        200,
        body: isHead ? null : audioBytes,
        headers: {
          'Content-Type': contentType,
          'Accept-Ranges': 'bytes',
          'Content-Length': '$total',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final range = _parseRange(rangeHeader, total);
    if (range == null) {
      return Response(
        416,
        body: isHead ? null : 'Range Not Satisfiable',
        headers: {
          'Content-Range': 'bytes */$total',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    final (start, end) = range;
    final length = end - start + 1;
    final slice = isHead ? null : Uint8List.sublistView(audioBytes, start, end + 1);
    _hitCount++;
    _logger.info(
      'MediaServer $method range=$start-$end/$total hit=$_hitCount',
      tag: 'MediaServer',
    );

    return Response(
      206,
      body: slice,
      headers: {
        'Content-Type': contentType,
        'Accept-Ranges': 'bytes',
        'Content-Range': 'bytes $start-$end/$total',
        'Content-Length': '$length',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  /// Parse `Range: bytes=start-end` / `bytes=start-`. Returns null if invalid.
  static (int, int)? parseRangeHeader(String header, int totalLength) =>
      _parseRange(header, totalLength);

  static (int, int)? _parseRange(String header, int totalLength) {
    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(header.trim());
    if (match == null) return null;

    final startRaw = match.group(1)!;
    final endRaw = match.group(2)!;

    if (startRaw.isEmpty && endRaw.isEmpty) return null;

    // Suffix form `bytes=-N` — last N bytes.
    if (startRaw.isEmpty) {
      final suffix = int.tryParse(endRaw);
      if (suffix == null || suffix <= 0) return null;
      final start = (totalLength - suffix).clamp(0, totalLength - 1);
      return (start, totalLength - 1);
    }

    final start = int.tryParse(startRaw);
    if (start == null || start < 0 || start >= totalLength) return null;

    final end = endRaw.isEmpty
        ? totalLength - 1
        : (int.tryParse(endRaw) ?? -1);
    if (end < start || end >= totalLength) {
      // Cast often sends `bytes=0-` which we already handle via empty end.
      if (endRaw.isEmpty) return (start, totalLength - 1);
      return null;
    }
    return (start, end);
  }

  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Typed media-server failure (hard requirement #3).
final class MediaServerFailure implements Exception {
  MediaServerFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'MediaServerFailure: $message';
}
