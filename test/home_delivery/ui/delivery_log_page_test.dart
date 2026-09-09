import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_log_dao.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/platform/oem_battery_settings.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_page.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

final class _FakeOem implements OemBatterySettingsPlatform {
  bool opened = false;

  @override
  Future<bool> canOpen() async => true;

  @override
  Future<bool> open() async {
    opened = true;
    return true;
  }

  @override
  Future<bool> openAutostartSettings() async => false;

  @override
  Future<bool> isRestrictiveOem() async => false;

  @override
  Future<bool> isBatteryUnrestricted() async => true;
}

void main() {
  late DeliveryDatabase db;
  late DeliveryLogDao dao;
  late _FakeOem oem;

  setUp(() {
    db = DeliveryDatabase.memory();
    dao = DeliveryLogDao(db);
    oem = _FakeOem();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryDatabaseProvider.overrideWithValue(db),
          oemBatterySettingsProvider.overrideWithValue(oem),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: PrayerCastTheme.light(),
          home: const DeliveryLogPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('renders last attempts with BI explanation', (tester) async {
    await dao.insertAttempt(
      sessionId: 'session-played01',
      prayer: 'maghrib',
      scheduledAtMs: DateTime.utc(2026, 8, 10, 19, 2).millisecondsSinceEpoch,
      outcome: Outcome.played,
      targetName: 'Kitchen Nest',
    );
    await dao.insertAttempt(
      sessionId: 'session-failed01',
      prayer: 'fajr',
      scheduledAtMs: DateTime.utc(2026, 8, 10, 5, 2).millisecondsSinceEpoch,
      firedAtMs: DateTime.utc(2026, 8, 10, 5, 3).millisecondsSinceEpoch,
      outcome: Outcome.failedNoTarget,
    );

    await pumpPage(tester);

    // Success rows are a single compact line (prayer · date · device · status).
    expect(find.textContaining('Maghrib'), findsOneWidget);
    expect(find.textContaining('Berhasil'), findsOneWidget);
    expect(find.textContaining('Kitchen Nest'), findsOneWidget);
    // Wire codes are not shown; failures use plain-language copy.
    expect(find.text('PLAYED'), findsNothing);
    expect(find.text('FAILED_NO_TARGET'), findsNothing);
    expect(find.text('Fajr'), findsOneWidget);
    expect(
      find.textContaining('Speaker tersimpan tidak ditemukan'),
      findsOneWidget,
    );
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Gagal saja'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      PrayerCastColors.ink,
    );
  });

  testWidgets('shows OEM battery banner after 2 FAILED_ALARM_MISSED in 7 days',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.insertAttempt(
      sessionId: 'missed-one000000',
      prayer: 'fajr',
      scheduledAtMs: now - 1000,
      outcome: Outcome.failedAlarmMissed,
    );
    await dao.insertAttempt(
      sessionId: 'missed-two000000',
      prayer: 'dhuhr',
      scheduledAtMs: now - 2000,
      outcome: Outcome.failedAlarmMissed,
    );

    await pumpPage(tester);

    expect(find.text('Buka pengaturan baterai'), findsOneWidget);
    await tester.tap(find.text('Buka pengaturan baterai'));
    await tester.pumpAndSettle();
    expect(oem.opened, isTrue);
  });

  testWidgets('hides OEM banner when fewer than 2 misses', (tester) async {
    await dao.insertAttempt(
      sessionId: 'missed-only-one0',
      prayer: 'fajr',
      scheduledAtMs: DateTime.now().millisecondsSinceEpoch,
      outcome: Outcome.failedAlarmMissed,
    );

    await pumpPage(tester);
    expect(find.text('Buka pengaturan baterai'), findsNothing);
  });
}
