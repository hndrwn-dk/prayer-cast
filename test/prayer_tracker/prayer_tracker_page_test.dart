import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_providers.dart';
import 'package:prayer_cast/prayer_tracker/prayer_tracker_store.dart';
import 'package:prayer_cast/prayer_tracker/ui/prayer_tracker_page.dart';

Future<void> _pumpTracker(
  WidgetTester tester, {
  Size size = const Size(320, 568),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 20, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 20, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerTrackerStoreProvider.overrideWithValue(MemoryPrayerTrackerStore()),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrayerTrackerPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('daily tracker clips under pinned header on a small phone', (
    tester,
  ) async {
    await _pumpTracker(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Prayer tracker'), findsOneWidget);
    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('5 prayers left to log today.'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Log tomorrow to start a streak.'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('0/5 prayers logged'), findsOneWidget);
    expect(find.text("Today's prayers"), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Reflection')).dy,
      lessThan(tester.getTopLeft(find.text('Streak')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Streak')).dy,
      lessThan(tester.getTopLeft(find.text('Summary')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Summary')).dy,
      lessThan(tester.getTopLeft(find.text("Today's prayers")).dy),
    );

    await tester.scrollUntilVisible(
      find.text('Fajr'),
      40,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -48));
    await tester.pump();
    expect(find.byKey(const ValueKey('prayer-icon-fajr')), findsOneWidget);

    await tester.tap(find.text('On time').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('On time · Alone'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Isha'),
      40,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Isha'), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer-icon-isha')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reflection card congratulates when all five are logged', (
    tester,
  ) async {
    final store = MemoryPrayerTrackerStore();
    final key = FilePrayerTrackerStore.dayKey(DateTime.now());
    await store.writeDay(key, {
      for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        prayer: const PrayerLogEntry(timing: PrayerLogTiming.onTime),
    });

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PrayerTrackerPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('Alhamdulillah — all 5 prayers logged today.'),
      40,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('5 prayers left to log today.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak card reads consecutive days from rhythm stats', (
    tester,
  ) async {
    final store = MemoryPrayerTrackerStore();
    final today = DateTime.now();
    const logged = PrayerLogEntry(timing: PrayerLogTiming.onTime);
    for (var i = 0; i < 3; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      await store.writeDay(FilePrayerTrackerStore.dayKey(day), {
        'fajr': logged,
      });
    }

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerTrackerStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PrayerTrackerPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('prayer_tracker_streak_value')),
      40,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('3'), findsWidgets);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('Log tomorrow to start a streak.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats page shows insights and a 30-day heatmap grid', (
    tester,
  ) async {
    await _pumpTracker(tester);
    await tester.tap(find.byKey(const ValueKey('prayer_tracker_stats_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Your rhythm'), findsWidgets);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.byKey(const ValueKey('prayer_heat_row')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Insights')).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('prayer_heat_row'))).dy),
    );

    await tester.tap(find.text('30 days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('prayer_heat_grid')), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
