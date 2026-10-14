import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';
import 'package:prayer_cast/dhikr/ui/widgets/counter_cell.dart';

Future<void> pumpCell(
  WidgetTester tester, {
  int count = 5,
  int target = 33,
  VoidCallback? onTap,
  VoidCallback? onReset,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CounterCell(
          state: DhikrCounterState(
            dhikrId: 'subhanallah',
            count: count,
            target: target,
          ),
          arabic: 'سُبْحَانَ اللهِ',
          translation: 'Glory be to Allah',
          onTap: onTap ?? () {},
          onReset: onReset ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('CounterCell', () {
    testWidgets('displays Arabic text and translation', (tester) async {
      await pumpCell(tester);
      expect(find.text('سُبْحَانَ اللهِ'), findsOneWidget);
      expect(find.text('Glory be to Allah'), findsOneWidget);
    });

    testWidgets('displays count and target', (tester) async {
      await pumpCell(tester, count: 15);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('/33'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await pumpCell(tester, onTap: () => tapped = true);
      await tester.tap(find.text('Glory be to Allah'));
      expect(tapped, true);
    });

    testWidgets('calls onReset when reset button tapped', (tester) async {
      var resetCalled = false;
      await pumpCell(tester, count: 25, onReset: () => resetCalled = true);
      final resetButton = find.byIcon(Icons.refresh);
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      expect(resetCalled, true);
    });

    testWidgets('calls onReset on long press without tapping', (tester) async {
      var resets = 0;
      var taps = 0;
      await pumpCell(
        tester,
        onTap: () => taps++,
        onReset: () => resets++,
      );
      await tester.longPress(find.text('Glory be to Allah'));
      expect(resets, 1);
      expect(taps, 0);
    });

    testWidgets('shows progress indicator with correct value', (tester) async {
      await pumpCell(tester, count: 16, target: 32);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
    });

    testWidgets('reset button meets minimum tap target', (tester) async {
      await pumpCell(tester);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
