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

    test('every item has id, transliteration and source', () {
      for (final list in [
        AdhkarContentData.morning(l10n),
        AdhkarContentData.evening(l10n),
      ]) {
        final ids = list.map((a) => a.id).toSet();
        expect(ids.length, list.length, reason: 'ids must be unique');
        for (final a in list) {
          expect(a.transliteration, isNotEmpty, reason: a.id);
          expect(a.source, isNotEmpty, reason: a.id);
        }
      }
    });

    test('morning and evening use their own wording', () {
      final morning = AdhkarContentData.morning(l10n);
      final evening = AdhkarContentData.evening(l10n);
      expect(morning.any((a) => a.arabic.startsWith('أَصْبَحْنَا')), true);
      expect(evening.any((a) => a.arabic.startsWith('أَمْسَيْنَا')), true);
      expect(morning.any((a) => a.arabic.startsWith('أَمْسَيْنَا')), false);
      expect(evening.any((a) => a.arabic.startsWith('أَصْبَحْنَا')), false);
    });

    test('quranic ayah markers carry Arabic-Indic numbers', () {
      const expectedCount = {
        'al-ikhlas': 4,
        'al-falaq': 5,
        'an-nas': 6,
        'ayat-kursi': 1,
      };
      const lastMarker = {
        'al-ikhlas': '۝٤',
        'al-falaq': '۝٥',
        'an-nas': '۝٦',
        'ayat-kursi': '۝٢٥٥',
      };
      final bareMarker = RegExp('۝(?![٠-٩])');
      for (final list in [
        AdhkarContentData.morning(l10n),
        AdhkarContentData.evening(l10n),
      ]) {
        for (final entry in expectedCount.entries) {
          final item = list.singleWhere((a) => a.id == entry.key);
          expect(bareMarker.hasMatch(item.arabic), isFalse, reason: item.id);
          expect(
            '۝'.allMatches(item.arabic).length,
            entry.value,
            reason: item.id,
          );
          expect(item.arabic.endsWith(lastMarker[entry.key]!), isTrue, reason: item.id);
        }
        for (final item in list) {
          if (expectedCount.containsKey(item.id)) continue;
          expect(item.arabic.contains('۝'), isFalse, reason: item.id);
        }
      }
    });

    test('after-prayer 33/33/34 tasbih is not part of evening adhkar', () {
      final evening = AdhkarContentData.evening(l10n);
      expect(evening.where((a) => a.count == 33 || a.count == 34), isEmpty);
    });
  });
}
