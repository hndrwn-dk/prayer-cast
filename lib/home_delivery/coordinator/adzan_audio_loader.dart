import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../common/logger.dart';

/// Loads bundled adzan audio for [voiceId] (`assets/audio/{voiceId}.mp3`).
abstract interface class AdzanAudioLoader {
  Future<Uint8List> load(String voiceId);
}

/// Asset-backed loader with a clearly labeled silent test-tone fallback.
///
/// OPEN TASK: real adzan MP3 recordings are not yet in `assets/audio/`. Until
/// they are sourced, missing assets fall back to a short silent MPEG frame so
/// the delivery pipeline can still be wired and tested.
final class AssetAdzanAudioLoader implements AdzanAudioLoader {
  AssetAdzanAudioLoader({
    AssetBundle? bundle,
    HomeDeliveryLogger logger = const SilentLogger(),
  })  : _bundle = bundle ?? rootBundle,
        _logger = logger;

  final AssetBundle _bundle;
  final HomeDeliveryLogger _logger;

  @override
  Future<Uint8List> load(String voiceId) async {
    final key = 'assets/audio/$voiceId.mp3';
    try {
      final data = await _bundle.load(key);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (e, st) {
      _logger.warn(
        'OPEN TASK: missing $key — using silent test tone (not production audio)',
        tag: 'AdzanAudioLoader',
        error: e,
        stackTrace: st,
      );
      return Uint8List.fromList(silentTestToneMpeg);
    }
  }
}

/// Minimal valid MPEG-1 Layer III frame (silence). Wiring / CI only.
///
/// Label: SILENT_TEST_TONE — replace with real adzan recordings before release.
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
