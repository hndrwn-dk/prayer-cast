import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/app_settings_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/l10n/locale_controller.dart';
import 'package:prayer_cast/theme/app_theme_store.dart';

void main() {
  testWidgets('forest brightness uses ink surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            expect(PrayerCastTokens.isForest(context), isTrue);
            expect(PrayerCastTokens.surface(context), PrayerCastColors.ink);
            expect(
              PrayerCastTokens.onSurface(context),
              PrayerCastColors.surfaceRaised,
            );
            expect(PrayerCastTokens.hairline(context), PrayerCastColors.dawn);
            expect(
              PrayerCastTokens.systemUi(context),
              PrayerCastTheme.forestSystemUi,
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('light brightness uses mist surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.light,
        home: Builder(
          builder: (context) {
            expect(PrayerCastTokens.isForest(context), isFalse);
            expect(PrayerCastTokens.surface(context), PrayerCastColors.surface);
            expect(PrayerCastTokens.onSurface(context), PrayerCastColors.ink);
            expect(PrayerCastTokens.hairline(context), PrayerCastColors.dawn);
            expect(
              PrayerCastTokens.systemUi(context),
              PrayerCastTheme.mistSystemUi,
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('settings page stays light without a forest wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeStoreProvider.overrideWithValue(MemoryLocaleStore('en')),
          appThemeStoreProvider.overrideWithValue(MemoryAppThemeStore()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PrayerCastTheme.light(),
          darkTheme: PrayerCastTheme.forest(),
          themeMode: ThemeMode.light,
          home: const AppSettingsPage(version: '1.0.0'),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byKey(AppSettingsPage.keyName));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('light slab is dark type on a light fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.light,
        home: const Scaffold(body: InkSurface(child: Text('Fajr'))),
      ),
    );

    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(InkSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, PrayerCastColors.surface);
    expect(decoration.color, isNot(PrayerCastColors.canopyDeep));

    final color = DefaultTextStyle.of(
      tester.element(find.text('Fajr')),
    ).style.color;
    expect(color, PrayerCastColors.inkSoft);
    expect(color, isNot(PrayerCastColors.mist));
    expect(color, isNot(PrayerCastColors.surfaceRaised));
  });

  testWidgets('forest slab stays canopyDeep', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: InkSurface(child: Text('Fajr'))),
      ),
    );

    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(InkSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, PrayerCastColors.canopyDeep);
  });

  testWidgets('light tracker wells are opaque mist with ink type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.light,
        home: Builder(
          builder: (context) {
            expect(
              PrayerCastTokens.inkWash(context, 0.45),
              PrayerCastColors.mist,
            );
            expect(PrayerCastTokens.inkWash(context, 0.35).a, 1);
            expect(
              PrayerCastTokens.leafWash(context, 0.35),
              PrayerCastColors.mistDeep,
            );
            expect(
              PrayerCastTokens.segmentFill(context),
              PrayerCastColors.mistDeep,
            );
            expect(PrayerCastTokens.washLabel(context), PrayerCastColors.ink);
            expect(
              PrayerCastTokens.washEmphasis(context),
              PrayerCastColors.ink,
            );
            expect(PrayerCastTokens.washDetail(context), PrayerCastColors.ink);
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('forest tracker wells keep canopy washes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrayerCastTheme.light(),
        darkTheme: PrayerCastTheme.forest(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            expect(
              PrayerCastTokens.inkWash(context, 0.45),
              PrayerCastColors.ink.withValues(alpha: 0.45),
            );
            expect(
              PrayerCastTokens.inkWash(context, 0.35),
              PrayerCastColors.ink.withValues(alpha: 0.35),
            );
            expect(
              PrayerCastTokens.leafWash(context, 0.35),
              PrayerCastColors.leaf.withValues(alpha: 0.35),
            );
            expect(
              PrayerCastTokens.segmentFill(context),
              PrayerCastColors.leaf,
            );
            expect(PrayerCastTokens.washLabel(context), PrayerCastColors.mist);
            expect(
              PrayerCastTokens.washEmphasis(context),
              PrayerCastColors.surfaceRaised,
            );
            expect(
              PrayerCastTokens.washDetail(context),
              PrayerCastColors.mistDeep,
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
