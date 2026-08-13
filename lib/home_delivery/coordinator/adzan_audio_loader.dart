import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../common/logger.dart';

/// Loaded adzan audio bytes + MIME type for Cast.
final class AdzanAudioData {
  const AdzanAudioData({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
}

/// Loads bundled adzan audio for [voiceId].
abstract interface class AdzanAudioLoader {
  Future<AdzanAudioData> load(String voiceId);
}

/// Asset-backed loader. Tries `.mp3` then `.wav`.
final class AssetAdzanAudioLoader implements AdzanAudioLoader {
  AssetAdzanAudioLoader({
    AssetBundle? bundle,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _bundle = bundle ?? rootBundle,
        _logger = logger;

  final AssetBundle _bundle;
  final HomeDeliveryLogger _logger;

  @override
  Future<AdzanAudioData> load(String voiceId) async {
    for (final ext in const ['mp3', 'wav']) {
      final key = 'assets/audio/$voiceId.$ext';
      try {
        final data = await _bundle.load(key);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        return AdzanAudioData(
          bytes: bytes,
          contentType: ext == 'wav' ? 'audio/wav' : 'audio/mpeg',
          extension: ext,
        );
      } catch (_) {
        // try next extension
      }
    }

    _logger.warn(
      'OPEN TASK: missing assets/audio/$voiceId.(mp3|wav) — using silent test tone',
      tag: 'AdzanAudioLoader',
    );
    return AdzanAudioData(
      bytes: Uint8List.fromList(silentTestToneMpeg),
      contentType: 'audio/mpeg',
      extension: 'mp3',
    );
  }
}

/// Minimal valid MPEG-1 Layer III frame (silence). Wiring / CI only.
final List<int> silentTestToneMpeg = <int>[
  0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
];
