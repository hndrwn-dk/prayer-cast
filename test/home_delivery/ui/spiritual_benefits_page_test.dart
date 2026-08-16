import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/ui/spiritual_benefits_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/spiritual_benefits_teaser.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

void main() {
  testWidgets('home one-liner taps through to the spiritual benefits card', (
    tester,
  ) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
        nextPrayer: NextPrayer(
          name: 'dhuhr',
          scheduledAt: DateTime(2026, 8, 16, 14, 7),
          voiceId: 'standard_adhan',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(
      find.byKey(SpiritualBenefitsTeaserLine.keyName),
      findsOneWidget,
    );
    expect(
      find.text('Dzuhur · Isi ulang spiritual di tengah hari'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(SpiritualBenefitsTeaserLine.keyName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(SpiritualBenefitsPage.keyName), findsOneWidget);
    expect(find.text('Dzuhur'), findsWidgets);
    expect(find.text('MANFAAT SPIRITUAL'), findsWidgets);
    expect(find.text('AMALAN SUNNAH'), findsOneWidget);
    expect(find.text('CATATAN'), findsOneWidget);
    expect(find.text('Isi ulang spiritual di tengah hari'), findsWidgets);
    expect(
      find.text(
        'Sholat pertengahan yang menyeimbangkan hari dan mengingatkan kita pada tujuan.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('page shows Dhuhr sections in English', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.forest(),
        home: const SpiritualBenefitsPage(prayer: 'dhuhr'),
      ),
    );
    await tester.pump();

    expect(find.byKey(SpiritualBenefitsPage.keyName), findsOneWidget);
    expect(find.text('Dhuhr'), findsOneWidget);
    expect(find.text('SPIRITUAL BENEFITS'), findsWidgets);
    expect(find.text('SUNNAH PRACTICES'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('SAYING'), findsNothing);
    expect(find.text('Break from worldly activities'), findsOneWidget);
    expect(find.text('Midday spiritual recharge'), findsOneWidget);
    expect(find.text('Pray 4 Sunnah rakats before Dhuhr'), findsOneWidget);
    expect(
      find.text(
        'The middle prayer that brings balance to our day and reminds us of our purpose.',
      ),
      findsOneWidget,
    );
  });
}
