import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, DhikrCounterStore store) async {
  tester.view.physicalSize = const Size(800, 6000);
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
    testWidgets('displays list of dhikr counters', (tester) async {
      await _pump(tester, MemoryDhikrCounterStore());

      expect(find.text('سُبْحَانَ اللهِ'), findsOneWidget);
      expect(find.text('اَلْحَمْدُ لِلَّه'), findsOneWidget);
      expect(find.text('اَللهُ أَكْبَرُ'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNWidgets(7));
    });

    testWidgets('increments counter on tap', (tester) async {
      final store = MemoryDhikrCounterStore();
      await _pump(tester, store);

      await tester.tap(find.text('سُبْحَانَ اللهِ'));
      await tester.pumpAndSettle();

      expect((await store.get('subhanallah'))?.count, 1);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('resets counter on reset button tap', (tester) async {
      final store = MemoryDhikrCounterStore();
      await store.increment('subhanallah', target: 33);
      await store.increment('subhanallah', target: 33);
      await _pump(tester, store);

      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pumpAndSettle();

      expect((await store.get('subhanallah'))?.count, 0);
    });
  });
}
