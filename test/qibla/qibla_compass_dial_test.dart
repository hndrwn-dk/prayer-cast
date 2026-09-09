import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/qibla/ui/qibla_compass_dial.dart';

Future<void> _pumpDial(
  WidgetTester tester, {
  required double qiblaDeg,
  required double? headingDeg,
  bool aligned = false,
  bool isId = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: QiblaCompassDial(
            qiblaDeg: qiblaDeg,
            headingDeg: headingDeg,
            aligned: aligned,
            isId: isId,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<double> _rotations(WidgetTester tester) {
  return tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(QiblaCompassDial),
          matching: find.byType(Transform),
        ),
      )
      .map((t) => math.atan2(t.transform.entry(1, 0), t.transform.entry(0, 0)))
      .toList();
}

void main() {
  testWidgets('rose counter-rotates the heading, needle points at the qibla', (
    tester,
  ) async {
    await _pumpDial(tester, qiblaDeg: 295, headingDeg: 40);

    final rotations = _rotations(tester);
    expect(rotations, hasLength(2));
    // Rose first, then needle. The rose turn is what the painter negates so
    // the N/E/S/W glyphs stay upright.
    expect(rotations.first, closeTo(-40 * math.pi / 180, 0.001));
    expect(
      math.sin(rotations.last),
      closeTo(math.sin((295 - 40) * math.pi / 180), 0.001),
    );
  });

  testWidgets('missing heading parks the dial at north without throwing', (
    tester,
  ) async {
    await _pumpDial(tester, qiblaDeg: 295, headingDeg: null);

    expect(_rotations(tester).first, closeTo(0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints across a full turn in both languages', (tester) async {
    for (var heading = 0.0; heading < 360; heading += 15) {
      await _pumpDial(
        tester,
        qiblaDeg: 295,
        headingDeg: heading,
        aligned: heading > 290 && heading < 300,
        isId: heading.toInt() % 30 == 0,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('exposes the bearing to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpDial(tester, qiblaDeg: 295, headingDeg: 0);
    expect(find.bySemanticsLabel('Qibla compass'), findsOneWidget);

    await _pumpDial(tester, qiblaDeg: 295, headingDeg: 0, isId: true);
    expect(find.bySemanticsLabel('Kompas kiblat'), findsOneWidget);
    handle.dispose();
  });
}
