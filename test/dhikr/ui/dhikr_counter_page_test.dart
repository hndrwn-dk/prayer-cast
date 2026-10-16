import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_focus_page.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, DhikrCounterStore store) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dhikrCounterStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: DhikrCounterPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DhikrCounterPage', () {
    testWidgets('offers the after-prayer sequence and free counters', (
      tester,
    ) async {
      await _pump(tester, MemoryDhikrCounterStore());

      expect(find.byKey(DhikrCounterPage.afterPrayerKey), findsOneWidget);
      expect(find.text('FREE DHIKR'), findsOneWidget);
      expect(find.text('سُبْحَانَ اللهِ'), findsOneWidget);
      expect(find.text('أَسْتَغْفِرُ اللهَ'), findsOneWidget);
    });

    testWidgets('shows saved progress on a free counter', (tester) async {
      final store = MemoryDhikrCounterStore();
      await store.increment('astaghfirullah', target: 100);
      await store.increment('astaghfirullah', target: 100);
      final handle = tester.ensureSemantics();
      await _pump(tester, store);

      expect(
        find.bySemanticsLabel('I seek forgiveness from Allah, 2 / 100'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a free counter opens focus mode', (tester) async {
      await _pump(tester, MemoryDhikrCounterStore());
      await tester.tap(find.text('أَسْتَغْفِرُ اللهَ'));
      await tester.pumpAndSettle();

      expect(find.byType(DhikrFocusPage), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
    });

    testWidgets('after-prayer opens the sequence on tasbih', (tester) async {
      await _pump(tester, MemoryDhikrCounterStore());
      await tester.tap(find.byKey(DhikrCounterPage.afterPrayerKey));
      await tester.pumpAndSettle();

      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('/ 33'), findsOneWidget);
    });
  });
}
