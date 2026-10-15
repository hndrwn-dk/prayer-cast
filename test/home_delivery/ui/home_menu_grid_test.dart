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
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
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
  ThemeData? theme,
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
        theme: theme ?? PrayerCastTheme.forest(),
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

    final keys = [
      timesKey,
      trackerKey,
      qiblaKey,
      morningKey,
      eveningKey,
      counterKey,
    ];
    final first = tester.getRect(find.byKey(keys.first));
    for (final key in keys.skip(1)) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.width, closeTo(first.width, 0.5), reason: '$key width');
      expect(rect.height, closeTo(first.height, 0.5), reason: '$key height');
    }
    final morning = tester.getRect(find.byKey(morningKey));
    final above = tester.getRect(find.byKey(timesKey));
    final tracker = tester.getRect(find.byKey(trackerKey));
    expect(morning.width, closeTo(above.width, 0.5));
    expect(morning.height, closeTo(above.height, 0.5));
    expect(tracker.left - above.right, closeTo(4, 0.5));
    expect(morning.top - above.bottom, closeTo(20, 0.5));
    final gridPadding = tester.widget<Padding>(
      find.byKey(HomeMenuGrid.gridKey),
    );
    final insets = gridPadding.padding.resolve(TextDirection.ltr);
    expect(insets.left, 12);
    expect(insets.right, 12);
    expect(
      tester.widget<Text>(find.text('Prayer times')).style?.color,
      PrayerCastColors.surfaceRaised,
    );
    expect(
      find.descendant(
        of: find.byKey(HomeMenuGrid.gridKey),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.borderRadius == BorderRadius.circular(18);
        }),
      ),
      findsNothing,
    );
    final circles = find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == PrayerCastColors.canopy;
    });
    expect(circles, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      expect(tester.getSize(circles.at(i)), const Size(72, 72));
      final border =
          (tester.widget<DecoratedBox>(circles.at(i)).decoration
                  as BoxDecoration)
              .border;
      expect(border, isA<Border>());
    }
    final quiet = tester.widget<DecoratedBox>(
      find.descendant(of: find.byKey(timesKey), matching: circles),
    );
    final quietSide =
        ((quiet.decoration as BoxDecoration).border! as Border).top;
    expect(quietSide.width, 1);
    expect(quietSide.color, PrayerCastColors.dawn.withValues(alpha: 0.35));
    expect((quiet.decoration as BoxDecoration).boxShadow, isEmpty);
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

    Future<void> openAndLeave(Finder target, Type page) async {
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(page), findsOneWidget);
      Navigator.of(tester.element(find.byType(page))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(page), findsNothing);
    }

    Finder circleOf(ValueKey<String> key) => find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color != null;
      }),
    );

    await openAndLeave(circleOf(timesKey), PrayerSettingsPage);
    await openAndLeave(find.text('Prayer times'), PrayerSettingsPage);
    await openAndLeave(circleOf(trackerKey), PrayerTrackerPage);
    await openAndLeave(find.text('Prayer tracker'), PrayerTrackerPage);
    await openAndLeave(circleOf(qiblaKey), QiblaPage);
    await openAndLeave(find.text('Qibla/Mosque'), QiblaPage);
    await openAndLeave(circleOf(morningKey), MorningAdhkarPage);
    await openAndLeave(find.text('Morning Adhkar'), MorningAdhkarPage);
    await openAndLeave(circleOf(eveningKey), EveningAdhkarPage);
    await openAndLeave(find.text('Evening Adhkar'), EveningAdhkarPage);
    await openAndLeave(circleOf(counterKey), DhikrCounterPage);
    await openAndLeave(find.text('Dhikr Counter'), DhikrCounterPage);
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
    expect(
      tester.getSemantics(find.byKey(eveningKey)).label,
      'Evening Adhkar, NOW',
    );
    final active = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(eveningKey),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              decoration.color == PrayerCastColors.canopy;
        }),
      ),
    );
    expect(
      ((active.decoration as BoxDecoration).border! as Border).top.width,
      2,
    );
    final badge = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(eveningKey),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.borderRadius == BorderRadius.circular(10);
        }),
      ),
    );
    expect((badge.decoration as BoxDecoration).color, homeMenuNowFillForest);
    expect(
      tester.getSemantics(find.byKey(morningKey)).label,
      isNot(contains('NOW')),
    );
  });

  testWidgets('no NOW badge at 10 pm', (tester) async {
    await _pump(tester, now: DateTime(2026, 10, 15, 22));

    expect(find.text('NOW'), findsNothing);
    expect(find.text('SEKARANG'), findsNothing);
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

  testWidgets('light circles are white with the shared ink shadow', (
    tester,
  ) async {
    await _pump(
      tester,
      now: DateTime(2026, 10, 15, 22),
      theme: PrayerCastTheme.light(),
    );

    final circles = find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == Colors.white;
    });
    expect(circles, findsNWidgets(6));
    final decoration =
        tester.widget<DecoratedBox>(circles.first).decoration as BoxDecoration;
    final shadows = decoration.boxShadow;
    expect(shadows, hasLength(2));
    expect(shadows!.first.blurRadius, 2);
    expect(shadows.first.offset, const Offset(0, 1));
    expect(shadows.last.blurRadius, 16);
    expect(shadows.last.offset, const Offset(0, 6));
  });

  testWidgets('indonesian labels do not overflow at 320 with text scale 1.3', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loader = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'));
    await loader.load();
    await _pump(
      tester,
      now: DateTime(2026, 10, 15, 22),
      locale: const Locale('id'),
      textScaler: const TextScaler.linear(1.3),
    );

    for (final label in [
      'Waktu sholat',
      'Catatan sholat',
      'Kiblat/Masjid',
      'Dzikir Pagi',
      'Dzikir Petang',
      'Counter Dzikir',
    ]) {
      expect(find.text(label), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.size.height, greaterThan(0), reason: label);
    }
    expect(find.text('NOW'), findsNothing);
    expect(find.text('SEKARANG'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(timesKey)).height,
      greaterThanOrEqualTo(112),
    );
  });
}
