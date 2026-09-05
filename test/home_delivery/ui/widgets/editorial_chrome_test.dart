import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';

void main() {
  testWidgets('ForestScaffold keeps header, body, and bar above viewPadding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      const MaterialApp(
        home: ForestScaffold(
          header: Text('Title'),
          body: Align(alignment: Alignment.bottomCenter, child: Text('Tail')),
          bottom: Text('Bar'),
        ),
      ),
    );

    expect(tester.getRect(find.text('Title')).top, greaterThanOrEqualTo(40));
    expect(
      tester.getRect(find.text('Bar')).bottom,
      lessThanOrEqualTo(800 - 48),
    );
    expect(
      tester.getRect(find.text('Tail')).bottom,
      lessThanOrEqualTo(800 - 48),
    );

    final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(
      regions.any((region) => region.value == PrayerCastTheme.forestSystemUi),
      isTrue,
    );
  });

  testWidgets('ForestScaffold body sits above the nav inset without a bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      const MaterialApp(
        home: ForestScaffold(
          header: Text('Title'),
          body: Align(alignment: Alignment.bottomCenter, child: Text('Tail')),
        ),
      ),
    );

    expect(
      tester.getRect(find.text('Tail')).bottom,
      lessThanOrEqualTo(800 - 48),
    );
  });

  testWidgets('ForestScrollScaffold pads scroll content above nav inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      const MaterialApp(
        home: ForestScrollScaffold(
          header: Text('Title'),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 700,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text('Tail'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tail'),
      80,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Title')).top, greaterThanOrEqualTo(40));
    expect(
      tester.getRect(find.text('Tail')).bottom,
      lessThanOrEqualTo(800 - 48),
    );
  });
}
