import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/storage/adhkar_prefs.dart';
import 'package:prayer_cast/dhikr/storage/dhikr_counter_store.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/home_menu_grid.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/prayer_times/ui/prayer_settings_page.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_providers.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_store.dart';
import 'package:prayer_cast/prayer_tracker/ui/prayer_tracker_page.dart';
import 'package:prayer_cast/qibla/compass_heading.dart';
import 'package:prayer_cast/qibla/qibla_providers.dart';
import 'package:prayer_cast/qibla/ui/qibla_page.dart';

AladhanDaySchedule _schedule() {
  NextPrayer slot(String name, int hour, int minute) => NextPrayer(
    name: name,
    scheduledAt: DateTime(2026, 10, 15, hour, minute),
    voiceId: 'standard_adhan',
  );
  return AladhanDaySchedule(
    date: DateTime(2026, 10, 15),
    timezone: 'Asia/Jakarta',
    latitude: 0,
    longitude: 0,
    methodName: 'test',
    slots: [
      slot('fajr', 5, 0),
      slot('dhuhr', 12, 0),
      slot('asr', 15, 30),
      slot('maghrib', 18, 0),
      slot('isha', 19, 10),
    ],
  );
}

class _QuietCompass implements CompassHeadingSource {
  @override
  Stream<CompassReading> readings() async* {
    yield const CompassReading.unavailable();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required DateTime now,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeMenuClockProvider.overrideWithValue(() => now),
        todayScheduleProvider.overrideWith((ref) async => _schedule()),
        adhkarPrefsProvider.overrideWithValue(MemoryAdhkarPrefs()),
        dhikrCounterStoreProvider.overrideWithValue(MemoryDhikrCounterStore()),
        prayerPrefsStoreProvider.overrideWithValue(MemoryPrayerPrefsStore()),
        prayerTrackerStoreProvider.overrideWithValue(
          MemoryPrayerTrackerStore(),
        ),
        compassHeadingSourceProvider.overrideWithValue(_QuietCompass()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: HomeMenuGrid(
              onPrayerTimes: () {},
              onPrayerTracker: () {},
              onQibla: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const morningKey = ValueKey<String>('home_morning_adhkar');
  const eveningKey = ValueKey<String>('home_evening_adhkar');
  const counterKey = ValueKey<String>('home_dhikr_counter');
  const timesKey = ValueKey<String>('home_prayer_times_slab');
  const trackerKey = ValueKey<String>('home_prayer_tracker_slab');
  const qiblaKey = ValueKey<String>('home_qibla_slab');

  testWidgets('six tiles, no old eyebrows or section title', (tester) async {
    await _pump(tester, now: DateTime(2026, 10, 15, 8));

    expect(find.text('Prayer times'), findsOneWidget);
    expect(find.text('Prayer tracker'), findsOneWidget);
    expect(find.text('Qibla/Mosque'), findsOneWidget);
    expect(find.text('Morning Adhkar'), findsOneWidget);
    expect(find.text('Evening Adhkar'), findsOneWidget);
    expect(find.text('Dhikr Counter'), findsOneWidget);
    expect(find.text('DHIKR & REMEMBRANCE'), findsNothing);
    expect(find.text('AFTER FAJR'), findsNothing);
    expect(find.text('AFTER ASR'), findsNothing);
    expect(find.text('ANYTIME'), findsNothing);
    expect(find.text('SCHEDULE'), findsNothing);
  });

  testWidgets('each tile opens its page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeMenuClockProvider.overrideWithValue(
            () => DateTime(2026, 10, 15, 8),
          ),
          todayScheduleProvider.overrideWith((ref) async => _schedule()),
          adhkarPrefsProvider.overrideWithValue(MemoryAdhkarPrefs()),
          dhikrCounterStoreProvider.overrideWithValue(
            MemoryDhikrCounterStore(),
          ),
          prayerPrefsStoreProvider.overrideWithValue(MemoryPrayerPrefsStore()),
          prayerTrackerStoreProvider.overrideWithValue(
            MemoryPrayerTrackerStore(),
          ),
          compassHeadingSourceProvider.overrideWithValue(_QuietCompass()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: HomeMenuGrid(
                  onPrayerTimes: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrayerSettingsPage(),
                      ),
                    );
                  },
                  onPrayerTracker: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrayerTrackerPage(),
                      ),
                    );
                  },
                  onQibla: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const QiblaPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openAndLeave(ValueKey<String> key, Type page) async {
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(page), findsOneWidget);
      Navigator.of(tester.element(find.byType(page))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(page), findsNothing);
    }

    await openAndLeave(timesKey, PrayerSettingsPage);
    await openAndLeave(trackerKey, PrayerTrackerPage);
    await openAndLeave(qiblaKey, QiblaPage);
    await openAndLeave(morningKey, MorningAdhkarPage);
    await openAndLeave(eveningKey, EveningAdhkarPage);
    await openAndLeave(counterKey, DhikrCounterPage);
  });

  testWidgets('NOW badge is on evening adhkar after Asr', (tester) async {
    await _pump(tester, now: DateTime(2026, 10, 15, 16));

    expect(
      find.descendant(of: find.byKey(eveningKey), matching: find.text('NOW')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(morningKey), matching: find.text('NOW')),
      findsNothing,
    );
  });

  testWidgets('NOW badge is absent from evening adhkar in the morning', (
    tester,
  ) async {
    await _pump(tester, now: DateTime(2026, 10, 15, 8));

    expect(
      find.descendant(of: find.byKey(eveningKey), matching: find.text('NOW')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byKey(morningKey), matching: find.text('NOW')),
      findsOneWidget,
    );
  });

  testWidgets('indonesian labels stay within two lines on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loader = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'));
    await loader.load();
    await _pump(
      tester,
      now: DateTime(2026, 10, 15, 8),
      locale: const Locale('id'),
    );

    for (final label in [
      'Waktu sholat',
      'Catatan sholat',
      'Kiblat/Masjid',
      'Dzikir Pagi',
      'Dzikir Petang',
      'Counter Dzikir',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
    expect(find.text('SEKARANG'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final tile = tester.getSize(find.byKey(timesKey));
    expect(tile.height, greaterThanOrEqualTo(124));
  });
}
