import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/data/adhkar_content_data.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    // Get English localizations
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('AdhkarContentData', () {
    test('morning adhkar returns non-empty list', () {
      final content = AdhkarContentData.morning(l10n);
      expect(content, isNotEmpty);
    });

    test('evening adhkar returns non-empty list', () {
      final content = AdhkarContentData.evening(l10n);
      expect(content, isNotEmpty);
    });

    test('morning adhkar has Arabic text', () {
      final content = AdhkarContentData.morning(l10n);
      for (final adhkar in content) {
        expect(adhkar.arabic, isNotEmpty);
        expect(adhkar.translation, isNotEmpty);
        expect(adhkar.count, greaterThan(0));
      }
    });

    test('evening adhkar has Arabic text', () {
      final content = AdhkarContentData.evening(l10n);
      for (final adhkar in content) {
        expect(adhkar.arabic, isNotEmpty);
        expect(adhkar.translation, isNotEmpty);
        expect(adhkar.count, greaterThan(0));
      }
    });

    test('morning includes Ayat al-Kursi', () {
      final content = AdhkarContentData.morning(l10n);
      final hasAyatAlKursi = content.any(
        (a) => a.arabic.contains('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'),
      );
      expect(hasAyatAlKursi, true);
    });

    test('evening includes Ayat al-Kursi', () {
      final content = AdhkarContentData.evening(l10n);
      final hasAyatAlKursi = content.any(
        (a) => a.arabic.contains('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'),
      );
      expect(hasAyatAlKursi, true);
    });

    test('Indonesian locale differs from English', () async {
      final id = await AppLocalizations.delegate.load(const Locale('id'));
      final en = AdhkarContentData.morning(l10n);
      final idc = AdhkarContentData.morning(id);
      expect(idc.length, en.length);
      expect(idc.any((a) => a.translation.isNotEmpty), true);
      final differing = [
        for (var i = 0; i < en.length; i++)
          if (en[i].translation != idc[i].translation) i
      ];
      expect(differing, isNotEmpty);
    });
  });
}
