import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';

void main() {
  group('AdhkarType', () {
    test('has morning and evening values', () {
      expect(AdhkarType.values, contains(AdhkarType.morning));
      expect(AdhkarType.values, contains(AdhkarType.evening));
    });

    test('converts to string', () {
      expect(AdhkarType.morning.name, 'morning');
      expect(AdhkarType.evening.name, 'evening');
    });

    test('parses from string', () {
      expect(AdhkarType.fromString('morning'), AdhkarType.morning);
      expect(AdhkarType.fromString('evening'), AdhkarType.evening);
    });

    test('throws on invalid string', () {
      expect(() => AdhkarType.fromString('invalid'), throwsArgumentError);
    });
  });
}
