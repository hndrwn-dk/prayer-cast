import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/prayer_times/indonesia_location.dart';

void main() {
  group('isIndonesiaCountry', () {
    for (final raw in [
      'Indonesia',
      'indonesia',
      'ID',
      'id',
      'IDN',
      'Republik Indonesia',
      'Republic of Indonesia',
      'RI',
    ]) {
      test('"$raw" is Indonesia', () {
        expect(isIndonesiaCountry(raw), isTrue);
      });
    }

    for (final raw in [
      'Singapore',
      'SG',
      'Malaysia',
      'United Kingdom',
      '',
      'Indiana',
    ]) {
      test('"$raw" is not Indonesia', () {
        expect(isIndonesiaCountry(raw), isFalse);
      });
    }
  });

  group('methodIdForCountryChange', () {
    test('Singapore to Indonesia selects Kemenag', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'Singapore',
          nextCountry: 'Indonesia',
          currentMethodId: defaultAladhanMethodId,
        ),
        kemenagMethodId,
      );
    });

    test('ID spelling variants select Kemenag', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'Singapore',
          nextCountry: 'Republik Indonesia',
          currentMethodId: 11,
        ),
        kemenagMethodId,
      );
    });

    test('leaving Indonesia restores previous Aladhan method', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'Indonesia',
          nextCountry: 'Singapore',
          currentMethodId: kemenagMethodId,
          previousAladhanMethodId: 3,
        ),
        3,
      );
    });

    test('leaving Indonesia defaults to MUIS 11', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'ID',
          nextCountry: 'Malaysia',
          currentMethodId: kemenagMethodId,
        ),
        defaultAladhanMethodId,
      );
    });

    test('manual Aladhan pick stays while country remains Indonesia', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'Indonesia',
          nextCountry: 'Indonesia',
          currentMethodId: 3,
        ),
        3,
      );
    });

    test('non-Indonesia stays on current Aladhan method', () {
      expect(
        methodIdForCountryChange(
          previousCountry: 'Singapore',
          nextCountry: 'Singapore',
          currentMethodId: 11,
        ),
        11,
      );
    });
  });

  group('methodIdForLocationDetect', () {
    test('GPS Indonesia selects Kemenag even if current is MUIS', () {
      expect(
        methodIdForLocationDetect(
          country: 'Indonesia',
          currentMethodId: 11,
        ),
        kemenagMethodId,
      );
    });

    test('GPS Singapore keeps MUIS 11', () {
      expect(
        methodIdForLocationDetect(
          country: 'Singapore',
          currentMethodId: 11,
        ),
        11,
      );
    });

    test('GPS Singapore while on Kemenag restores MUIS', () {
      expect(
        methodIdForLocationDetect(
          country: 'Singapore',
          currentMethodId: kemenagMethodId,
        ),
        defaultAladhanMethodId,
      );
    });
  });

  test('scheduleSourceKey distinguishes kemenag vs aladhan', () {
    expect(scheduleSourceKey(kemenagMethodId), 'kemenag');
    expect(scheduleSourceKey(11), 'aladhan');
    expect(scheduleSourceKey(3), 'aladhan');
  });
}
