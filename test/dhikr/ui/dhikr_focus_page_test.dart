import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/data/dhikr_catalog.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_focus_page.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

late AppLocalizations _en;

Future<void> _pump(
  WidgetTester tester,
  DhikrCounterStore store, {
  required List<DhikrSpec> steps,
  bool sequence = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dhikrCounterStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: DhikrFocusPage(steps: steps, sequence: sequence),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _tapArea = find.byKey(DhikrFocusPage.tapAreaKey);

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('DhikrFocusPage free counter', () {
    testWidgets('tapping anywhere counts and persists', (tester) async {
      final store = MemoryDhikrCounterStore();
      final spec = DhikrCatalog.free(_en).first;
      await _pump(tester, store, steps: [spec]);

      await tester.tap(_tapArea);
      await tester.tap(_tapArea);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect((await store.get(spec.id))?.count, 2);
    });

    testWidgets('undo removes one count', (tester) async {
      final store = MemoryDhikrCounterStore();
      final spec = DhikrCatalog.free(_en).first;
      await store.increment(spec.id, target: spec.target);
      await store.increment(spec.id, target: spec.target);
      await _pump(tester, store, steps: [spec]);

      await tester.tap(find.byTooltip('Undo last tap'));
      await tester.pumpAndSettle();

      expect((await store.get(spec.id))?.count, 1);
    });

    testWidgets('reset asks first and keeps the count on cancel', (
      tester,
    ) async {
      final store = MemoryDhikrCounterStore();
      final spec = DhikrCatalog.free(_en).first;
      await store.increment(spec.id, target: spec.target);
      await _pump(tester, store, steps: [spec]);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset this counter?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await store.get(spec.id))?.count, 1);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reset').last);
      await tester.pumpAndSettle();
      expect((await store.get(spec.id))?.count, 0);
    });
  });

  group('DhikrFocusPage after-prayer sequence', () {
    testWidgets('moves to the next dhikr when a step completes', (
      tester,
    ) async {
      final store = MemoryDhikrCounterStore();
      final steps = DhikrCatalog.afterPrayer(_en);
      for (var i = 0; i < 32; i++) {
        await store.increment(steps[0].id, target: 33);
      }
      await _pump(tester, store, steps: steps, sequence: true);
      expect(find.text('1 of 4'), findsOneWidget);

      await tester.tap(_tapArea);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text(steps[1].arabic), findsOneWidget);
    });

    testWidgets('resumes at the first unfinished step', (tester) async {
      final store = MemoryDhikrCounterStore();
      final steps = DhikrCatalog.afterPrayer(_en);
      for (var i = 0; i < 33; i++) {
        await store.increment(steps[0].id, target: 33);
      }
      await _pump(tester, store, steps: steps, sequence: true);

      expect(find.text('2 of 4'), findsOneWidget);
    });

    testWidgets('finishing the tahlil shows the done screen', (tester) async {
      final store = MemoryDhikrCounterStore();
      final steps = DhikrCatalog.afterPrayer(_en);
      for (final s in steps.take(3)) {
        for (var i = 0; i < s.target; i++) {
          await store.increment(s.id, target: s.target);
        }
      }
      await _pump(tester, store, steps: steps, sequence: true);
      expect(find.text('4 of 4'), findsOneWidget);

      await tester.tap(_tapArea);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Dhikr after prayer complete'), findsOneWidget);
    });

    testWidgets('a finished sequence starts over next time', (tester) async {
      final store = MemoryDhikrCounterStore();
      final steps = DhikrCatalog.afterPrayer(_en);
      for (final s in steps) {
        for (var i = 0; i < s.target; i++) {
          await store.increment(s.id, target: s.target);
        }
      }
      await _pump(tester, store, steps: steps, sequence: true);

      expect(find.text('1 of 4'), findsOneWidget);
      expect((await store.get(steps[0].id))?.count, 0);
    });
  });
}
