import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/home_dhikr_section.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

void main() {
  group('HomeDhikrSection', () {
    testWidgets('displays dhikr section title', (tester) async {
      final prefs = MemoryAdhkarPrefs();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [adhkarPrefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HomeDhikrSection()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DHIKR & REMEMBRANCE'), findsOneWidget);
    });

    testWidgets('displays three destination cells', (tester) async {
      final prefs = MemoryAdhkarPrefs();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [adhkarPrefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HomeDhikrSection()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Morning Adhkar'), findsOneWidget);
      expect(find.text('Evening Adhkar'), findsOneWidget);
      expect(find.text('Dhikr Counter'), findsOneWidget);
    });

    testWidgets('shows enabled badge when adhkar enabled', (tester) async {
      final prefs = MemoryAdhkarPrefs();
      await prefs.setEnabled(AdhkarType.morning, true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [adhkarPrefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HomeDhikrSection()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsOneWidget);
    });

    testWidgets('tapping morning cell opens morning page', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adhkarPrefsProvider.overrideWithValue(MemoryAdhkarPrefs()),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HomeDhikrSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('home_morning_adhkar')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MorningAdhkarPage), findsOneWidget);
    });
  });
}
