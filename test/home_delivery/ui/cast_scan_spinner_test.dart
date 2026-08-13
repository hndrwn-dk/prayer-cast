import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/cast_scan_spinner.dart';

void main() {
  testWidgets('CastScanSpinner paints without CircularProgressIndicator',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CastScanSpinner(size: 36)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CastScanSpinner), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CastScanSpinner), findsOneWidget);
  });
}
