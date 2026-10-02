import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/app_settings_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/l10n/locale_controller.dart';
import 'package:prayer_cast/theme/app_theme_store.dart';

void main() {
  testWidgets('forest and light theme choices update store and brightness', (
    tester,
  ) async {
    final store = MemoryAppThemeStore(AppThemeChoice.system);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeStoreProvider.overrideWithValue(MemoryLocaleStore('en')),
          appThemeStoreProvider.overrideWithValue(store),
        ],
        child: const _ThemedSettingsHost(),
      ),
    );
    await tester.pump();

    expect(find.byKey(AppSettingsPage.themeSystemKey), findsOneWidget);
    expect(find.byKey(AppSettingsPage.themeForestKey), findsOneWidget);
    expect(find.byKey(AppSettingsPage.themeLightKey), findsOneWidget);

    await tester.tap(find.byKey(AppSettingsPage.themeForestKey));
    await tester.pump();

    expect(await store.read(), AppThemeChoice.forest);
    expect(_materialThemeBrightness(tester), Brightness.dark);

    await tester.tap(find.byKey(AppSettingsPage.themeLightKey));
    await tester.pump();

    expect(await store.read(), AppThemeChoice.light);
    expect(_materialThemeBrightness(tester), Brightness.light);
  });
}

class _ThemedSettingsHost extends ConsumerWidget {
  const _ThemedSettingsHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(appThemeProvider);
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: PrayerCastTheme.light(),
      darkTheme: PrayerCastTheme.forest(),
      themeMode: themeModeFor(choice),
      themeAnimationDuration: Duration.zero,
      home: const AppSettingsPage(version: '1.0.0'),
    );
  }
}

Brightness _materialThemeBrightness(WidgetTester tester) {
  final theme = find.descendant(
    of: find.byType(MaterialApp),
    matching: find.byType(Theme),
  );
  return tester.widget<Theme>(theme.first).data.brightness;
}
