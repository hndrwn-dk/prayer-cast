import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/ui/app_settings_page.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/adhan_countdown.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/spiritual_benefits_teaser.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:prayer_cast/support/open_support_url.dart';
import 'package:prayer_cast/support/share_plain_text.dart';

const _prayerTimesSlab = ValueKey<String>('home_prayer_times_slab');

const _phonePadding = FakeViewPadding(top: 20, bottom: 34);

Future<void> _pumpHomeAtSize(
  WidgetTester tester, {
  required Size size,
  FakeViewPadding padding = _phonePadding,
  FakeViewPadding? viewPadding,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = padding;
  tester.view.viewPadding = viewPadding ?? padding;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);

  final db = DeliveryDatabase.memory();
  addTearDown(db.close);

  await tester.pumpWidget(
    PrayerCastAppForTest(
      database: db,
      prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
      nextPrayer: NextPrayer(
        name: 'isha',
        scheduledAt: DateTime(2026, 8, 13, 20, 25),
        voiceId: 'standard_adhan',
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home_settings')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(AppSettingsPage.keyName), findsOneWidget);
}

void main() {
  setUp(() {
    debugLaunchExternalUrl = (_) async => true;
  });
  tearDown(() {
    debugLaunchExternalUrl = null;
    debugShareText = null;
  });

  testWidgets('app shell loads speaker and prayer entry points', (
    tester,
  ) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(PrayerCastAppForTest(database: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(
      find.byKey(const ValueKey('onboarding_audio_speaker')),
      findsOneWidget,
    );
    expect(find.text('ADZAN BERIKUTNYA'), findsNothing);
  });

  testWidgets('settings holds language, adhan history, about, and legal', (
    tester,
  ) async {
    final launched = <Uri>[];
    final shared = <String>[];
    debugLaunchExternalUrl = (uri) async {
      launched.add(uri);
      return true;
    };
    debugShareText = (text) async => shared.add(text);

    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        onboarding: MemoryOnboardingStore(
          const OnboardingRecord(step: OnboardingStep.completed),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    await _openSettings(tester);
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Pilih bahasa yang Anda pakai'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Riwayat adzan'), findsOneWidget);
    expect(
      find.text('Apakah adzan sampai ke speaker, hanya di ponsel ini.'),
      findsOneWidget,
    );
    expect(find.text('TENTANG'), findsOneWidget);
    expect(find.text('Versi aplikasi'), findsOneWidget);
    expect(find.text(kAppVersion), findsOneWidget);
    expect(find.text('Beri rating aplikasi'), findsOneWidget);
    expect(find.text('Buka Play Store'), findsOneWidget);
    expect(find.text('Bagikan Prayer Cast'), findsOneWidget);
    expect(find.text('Undang teman memakai app ini'), findsOneWidget);
    expect(find.text('LEGAL'), findsOneWidget);
    expect(find.text('Kebijakan privasi'), findsOneWidget);
    expect(
      find.text('Bagaimana Prayer Cast memakai data di ponsel ini'),
      findsOneWidget,
    );

    final idLabel = tester.widget<Text>(find.text('Bahasa Indonesia'));
    final enLabel = tester.widget<Text>(find.text('English'));
    expect(idLabel.style?.fontWeight, FontWeight.w400);
    expect(enLabel.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.byKey(AppSettingsPage.deliveryLogKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Riwayat adzan'), findsWidgets);
    expect(find.textContaining('30 percobaan terakhir'), findsWidgets);
    await tester.tap(find.byTooltip('Kembali').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.byKey(AppSettingsPage.rateKey));
    await tester.tap(find.byKey(AppSettingsPage.rateKey));
    await tester.pump();
    expect(launched, [Uri.parse(AppLinks.playStoreUrl)]);

    await tester.ensureVisible(find.byKey(AppSettingsPage.shareKey));
    await tester.tap(find.byKey(AppSettingsPage.shareKey));
    await tester.pump();
    expect(shared, hasLength(1));
    expect(shared.single, contains(AppLinks.playStoreUrl));

    await tester.ensureVisible(find.byKey(AppSettingsPage.privacyKey));
    await tester.tap(find.byKey(AppSettingsPage.privacyKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.byKey(AppSettingsPage.termsKey));
    await tester.tap(find.byKey(AppSettingsPage.termsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(launched, [
      Uri.parse(AppLinks.playStoreUrl),
      Uri.parse(AppLinks.privacyPolicyUrl),
      Uri.parse(AppLinks.termsOfServiceUrl),
    ]);
    expect(find.textContaining('Gunakan lokasi saat ini'), findsNothing);
  });

  testWidgets('home next-adhan chip shows city and country', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
        nextPrayer: NextPrayer(
          name: 'isha',
          scheduledAt: DateTime(2026, 8, 13, 20, 25),
          voiceId: 'standard_adhan',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
    expect(find.text('Isya · 20:25'), findsNothing);
    expect(find.text('20:25'), findsOneWidget);
    expect(find.byKey(AdhanCountdownLabel.keyName), findsOneWidget);
    expect(find.textContaining('Isya sekarang'), findsOneWidget);
    expect(find.text('Singapore, Singapore'), findsNothing);
    expect(find.text('Kota: Singapore'), findsOneWidget);
    expect(find.text('Negara: Singapore'), findsOneWidget);
    expect(find.byKey(SpiritualBenefitsTeaserLine.keyName), findsOneWidget);

    final teaserBottom = tester
        .getBottomLeft(find.byKey(SpiritualBenefitsTeaserLine.keyName))
        .dy;
    final cityTop = tester.getTopLeft(find.text('Kota: Singapore')).dy;
    expect(cityTop - teaserBottom, lessThan(16));
    expect(cityTop - teaserBottom, greaterThan(4));
  });

  testWidgets('home destinations fit a short phone without overflow', (
    tester,
  ) async {
    await _pumpHomeAtSize(tester, size: const Size(320, 568));
    expect(find.text('PRAYER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Kebijakan privasi'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(HomeClosingNote.dividerKey, skipOffstage: false),
      64,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Data hanya tersimpan di ponsel Anda.'), findsOneWidget);
    expect(find.text('Kiblat/Masjid'), findsOneWidget);
    expect(find.byKey(_prayerTimesSlab), findsOneWidget);

    // Titles stay one line (same height) — no uneven wrap vs Qibla.
    final timesH = tester.getSize(find.text('Waktu sholat')).height;
    final trackerH = tester.getSize(find.text('Catatan sholat')).height;
    final qiblaH = tester.getSize(find.text('Kiblat/Masjid')).height;
    expect(timesH, closeTo(trackerH, 1));
    expect(trackerH, closeTo(qiblaH, 1));
  });

  testWidgets('home destinations stay on-screen on a tall phone', (
    tester,
  ) async {
    await _pumpHomeAtSize(tester, size: const Size(448, 1080));
    expect(tester.takeException(), isNull);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, lessThan(80));
    expect(find.byKey(_prayerTimesSlab), findsOneWidget);
    expect(find.text('Kiblat/Masjid'), findsOneWidget);
    expect(find.byKey(HomeClosingNote.dividerKey), findsOneWidget);
    final scaffoldH = tester.getSize(find.byType(Scaffold).first).height;
    expect(
      scaffoldH - tester.getBottomLeft(find.byType(HomeClosingNote)).dy,
      closeTo(tester.view.padding.bottom, 2),
    );
  });

  testWidgets('home destinations sit above the Android navigation inset', (
    tester,
  ) async {
    const navInset = 48.0;
    await _pumpHomeAtSize(
      tester,
      size: const Size(448, 1080),
      padding: FakeViewPadding.zero,
      viewPadding: const FakeViewPadding(top: 40, bottom: navInset),
    );

    expect(
      tester.getRect(find.byType(HomeClosingNote)).bottom,
      lessThanOrEqualTo(1080 - navInset),
    );
    expect(tester.getTopLeft(find.text('PRAYER')).dy, greaterThanOrEqualTo(40));
  });
}
