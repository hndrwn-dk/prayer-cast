import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_page_body.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

Future<MemoryAdhkarPrefs> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final prefs = MemoryAdhkarPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adhkarPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(AdhkarPageBody.settingsButtonKey));
  await tester.pumpAndSettle();
}

final _advance = find.byKey(AdhkarPageBody.advanceButtonKey);

void main() {
  group('MorningAdhkarPage', () {
    testWidgets('opens on the first dhikr, not on settings', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      expect(find.text('Morning Adhkar'), findsOneWidget);
      expect(find.text('1 of 25'), findsOneWidget);
      expect(
        find.textContaining('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'),
        findsOneWidget,
      );
      expect(find.text('Read 1x'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('read-once item advances with the button', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      await tester.tap(_advance);
      await tester.pumpAndSettle();
      expect(find.text('2 of 25'), findsOneWidget);
      expect(find.text('Read 3x'), findsOneWidget);
    });

    testWidgets('repeated item counts taps and moves on at the target', (
      tester,
    ) async {
      await _pump(tester, const MorningAdhkarPage());
      await tester.tap(_advance); // Ayat al-Kursi, 1x
      await tester.pumpAndSettle();

      await tester.tap(_advance);
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(_advance);
      await tester.pump();
      await tester.tap(_advance);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('3 of 25'), findsOneWidget);
    });

    testWidgets('undo takes one count back', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      await tester.tap(_advance);
      await tester.pumpAndSettle();
      await tester.tap(_advance);
      await tester.tap(_advance);
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Undo last tap'));
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('settings sheet toggles speaker auto-play', (tester) async {
      final prefs = await _pump(tester, const MorningAdhkarPage());
      await _openSettings(tester);
      expect(find.text('Play on speaker now'), findsOneWidget);
      expect(prefs.enabled(AdhkarType.morning), false);

      await tester.tap(find.text('Auto-play on speaker'));
      await tester.pumpAndSettle();
      expect(prefs.enabled(AdhkarType.morning), true);
      expect(find.text('10 min after Fajr'), findsOneWidget);
    });

    testWidgets('transliteration can be hidden', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      expect(find.textContaining('Allaahu laa ilaaha'), findsOneWidget);

      await _openSettings(tester);
      await tester.tap(find.text('Transliteration'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 40)); // dismiss the sheet
      await tester.pumpAndSettle();

      expect(find.textContaining('Allaahu laa ilaaha'), findsNothing);
    });
  });

  group('EveningAdhkarPage', () {
    testWidgets('toggles evening only', (tester) async {
      final prefs = await _pump(tester, const EveningAdhkarPage());
      expect(find.text('Evening Adhkar'), findsOneWidget);
      await _openSettings(tester);
      await tester.tap(find.text('Auto-play on speaker'));
      await tester.pumpAndSettle();
      expect(prefs.enabled(AdhkarType.evening), true);
      expect(prefs.enabled(AdhkarType.morning), false);
      expect(find.text('5 min after Asr'), findsOneWidget);
    });
  });
}
