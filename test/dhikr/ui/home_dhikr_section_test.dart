import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/home_dhikr_section.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adhkarPrefsProvider.overrideWithValue(MemoryAdhkarPrefs()),
        dhikrCounterStoreProvider.overrideWithValue(MemoryDhikrCounterStore()),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: HomeDhikrSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HomeDhikrSection', () {
    testWidgets('three cells with eyebrows, like the strip above', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('AFTER FAJR'), findsOneWidget);
      expect(find.text('AFTER ASR'), findsOneWidget);
      expect(find.text('ANYTIME'), findsOneWidget);
      expect(find.text('Morning Adhkar'), findsOneWidget);
      expect(find.text('Evening Adhkar'), findsOneWidget);
      expect(find.text('Dhikr Counter'), findsOneWidget);
      expect(find.text('Enabled'), findsNothing);
    });

    testWidgets('cells share one row and equal widths', (tester) async {
      await _pump(tester);
      final a = tester.getRect(
        find.byKey(const ValueKey<String>('home_morning_adhkar')),
      );
      final b = tester.getRect(
        find.byKey(const ValueKey<String>('home_evening_adhkar')),
      );
      final c = tester.getRect(
        find.byKey(const ValueKey<String>('home_dhikr_counter')),
      );
      expect(a.top, b.top);
      expect(b.top, c.top);
      expect(a.width, closeTo(b.width, 0.5));
      expect(b.width, closeTo(c.width, 0.5));
    });

    testWidgets('morning cell opens morning page', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('home_morning_adhkar')));
      await tester.pumpAndSettle();
      expect(find.byType(MorningAdhkarPage), findsOneWidget);
    });

    testWidgets('counter cell opens counter page', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('home_dhikr_counter')));
      await tester.pumpAndSettle();
      expect(find.byType(DhikrCounterPage), findsOneWidget);
    });
  });
}
