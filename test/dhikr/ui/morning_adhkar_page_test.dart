import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

Future<MemoryAdhkarPrefs> _pump(WidgetTester tester, Widget page) async {
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
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  group('MorningAdhkarPage', () {
    testWidgets('displays title, toggle and Test now button', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      expect(find.text('Morning Adhkar'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Test now'), findsOneWidget);
    });

    testWidgets('displays adhkar content with counts', (tester) async {
      await _pump(tester, const MorningAdhkarPage());
      await tester.scrollUntilVisible(
        find.textContaining('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'),
        findsOneWidget,
      );
      expect(find.text('1x'), findsWidgets);
    });

    testWidgets('toggles enabled state', (tester) async {
      final prefs = await _pump(tester, const MorningAdhkarPage());
      expect(prefs.enabled(AdhkarType.morning), false);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.enabled(AdhkarType.morning), true);
    });
  });

  group('EveningAdhkarPage', () {
    testWidgets('displays title and toggles evening', (tester) async {
      final prefs = await _pump(tester, const EveningAdhkarPage());
      expect(find.text('Evening Adhkar'), findsOneWidget);
      expect(find.text('Test now'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.enabled(AdhkarType.evening), true);
      expect(prefs.enabled(AdhkarType.morning), false);
    });
  });
}
