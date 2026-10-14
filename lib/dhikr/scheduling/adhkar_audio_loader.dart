import 'package:flutter/services.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';

/// Loads adhkar audio from assets/audio/Adhkar/adhkar_{morning,evening}.mpeg.
final class AdhkarAudioLoader {
  AdhkarAudioLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String _assetPath = 'assets/audio/Adhkar';

  final AssetBundle _bundle;

  /// Returns raw MPEG bytes, or null if the asset is missing or unreadable.
  Future<Uint8List?> load(AdhkarType type) async {
    final filename = type == AdhkarType.morning
        ? 'adhkar_morning.mpeg'
        : 'adhkar_evening.mpeg';
    try {
      final data = await _bundle.load('$_assetPath/$filename');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(AdhkarType type) async => await load(type) != null;
}
