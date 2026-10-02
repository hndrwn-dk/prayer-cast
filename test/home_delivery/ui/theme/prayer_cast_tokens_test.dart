import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/app_settings_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/l10n/locale_controller.dart';

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
}
