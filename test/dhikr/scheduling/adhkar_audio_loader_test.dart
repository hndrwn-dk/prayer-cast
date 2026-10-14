import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_audio_loader.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.assets);
  final Map<String, List<int>> assets;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdhkarAudioLoader', () {
    test('loads morning and evening audio from correct paths', () async {
      final bundle = _FakeBundle({
        'assets/audio/Adhkar/adhkar_morning.mpeg': [1, 2, 3],
        'assets/audio/Adhkar/adhkar_evening.mpeg': [4, 5],
      });
      final loader = AdhkarAudioLoader(bundle: bundle);

      expect(await loader.load(AdhkarType.morning), [1, 2, 3]);
      expect(await loader.load(AdhkarType.evening), [4, 5]);
    });

    test('returns null when asset is missing', () async {
      final loader = AdhkarAudioLoader(bundle: _FakeBundle({}));
      expect(await loader.load(AdhkarType.morning), isNull);
      expect(await loader.exists(AdhkarType.evening), isFalse);
    });

    test('exists is true when asset present', () async {
      final loader = AdhkarAudioLoader(
        bundle: _FakeBundle({'assets/audio/Adhkar/adhkar_morning.mpeg': [1]}),
      );
      expect(await loader.exists(AdhkarType.morning), isTrue);
    });
  });
}
