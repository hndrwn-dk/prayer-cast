import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/play_store_caption_bar.dart';

void main() {
  testWidgets('caption bar shows the English overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
      ),
    );
    expect(find.text('Adhan on the speaker at home.'), findsOneWidget);
  });

  testWidgets('forest panel is canopyDeep with a dawn hairline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.dark,
        home: const PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
      ),
    );

    final decoration =
        tester
                .widget<DecoratedBox>(find.byKey(PlayStoreCaptionBar.panelKey))
                .decoration
            as BoxDecoration;
    expect(decoration.color, PrayerCastColors.canopyDeep);
    expect(
      tester.widget<EditorialHairline>(find.byType(EditorialHairline)).color,
      PrayerCastColors.dawn,
    );
  });

  testWidgets('light panel uses PrayerCastTokens.surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.light,
        home: const PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
      ),
    );

    final decoration =
        tester
                .widget<DecoratedBox>(find.byKey(PlayStoreCaptionBar.panelKey))
                .decoration
            as BoxDecoration;
    expect(decoration.color, PrayerCastColors.surface);
    expect(decoration.color, isNot(PrayerCastColors.canopyDeep));
  });

  testWidgets('caption is Fraunces 22 on an Atkinson 16 panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.forest(),
        home: const PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
      ),
    );

    final caption = tester.widget<Text>(
      find.text('Adhan on the speaker at home.'),
    );
    expect(caption.style!.fontFamily, PrayerCastTheme.displayFont);
    expect(caption.style!.fontSize, 22);

    final ambient = DefaultTextStyle.of(
      tester.element(find.text('Adhan on the speaker at home.')),
    );
    expect(ambient.style.fontFamily, PrayerCastTheme.bodyFont);
    expect(ambient.style.fontSize, 16);
  });

  testWidgets('panel is full width, padded 24, and pinned to the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
      ),
    );

    expect(tester.getSize(find.byKey(PlayStoreCaptionBar.panelKey)).width, 400);
    expect(
      tester
          .widget<Padding>(find.byKey(PlayStoreCaptionBar.paddingKey))
          .padding,
      const EdgeInsets.all(24),
    );
    expect(tester.getTopLeft(find.byKey(PlayStoreCaptionBar.panelKey)).dy, 0);
    expect(
      tester.getTopLeft(find.text('Adhan on the speaker at home.')).dy,
      24,
    );
    expect(
      tester.getBottomLeft(find.byKey(PlayStoreCaptionBar.panelKey)).dy,
      lessThan(400),
    );
  });
}
