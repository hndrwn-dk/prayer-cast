import 'dart:ui' show FakeViewPadding;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/adhan_countdown.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

const _privacyLine = 'Data hanya tersimpan di ponsel Anda.';
const _prayerTimesSlab = ValueKey<String>('home_prayer_times_slab');

/// Notch + gesture inset typical of modern Android / iPhone-class phones.
const _phonePadding = FakeViewPadding(top: 20, bottom: 34);

Future<void> _pumpHomeAtSize(
  WidgetTester tester, {
  required Size size,
  FakeViewPadding padding = _phonePadding,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
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

void _expectHairlineImmediatelyAboveFootnotes(WidgetTester tester) {
  final divider = find.byKey(ColophonFootnote.dividerKey);
  expect(divider, findsOneWidget);
  expect(find.text(_privacyLine), findsOneWidget);
  expect(find.text('version: $kAppVersion'), findsOneWidget);
  expect(tester.takeException(), isNull);

  final dividerBottom = tester.getBottomLeft(divider).dy;
  final footnoteTop = tester.getTopLeft(find.text(_privacyLine)).dy;
  expect(footnoteTop - dividerBottom, closeTo(14, 1));

  final prayerRect = tester.getRect(find.byKey(_prayerTimesSlab));
  final footnoteRect = tester.getRect(find.text(_privacyLine));
  expect(prayerRect.overlaps(footnoteRect), isFalse);
  expect(
    tester.getTopLeft(divider).dy,
    greaterThanOrEqualTo(prayerRect.bottom - 1),
  );
}

void main() {
  testWidgets('app shell loads speaker and prayer entry points', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(PrayerCastAppForTest(database: db));
    // Entrance delays + fade controllers (avoid pumpAndSettle: BreathPulse loops).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('PRAYER'), findsOneWidget);
    expect(find.text('Cast'), findsOneWidget);
    expect(find.byKey(const ValueKey('support_on_kofi')), findsOneWidget);
    expect(find.byKey(const ValueKey('language_menu')), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.text('EN'), findsNothing);
    expect(find.text('ID'), findsNothing);
    expect(find.text('Beranda'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Data hanya tersimpan di ponsel Anda.'), findsOneWidget);
    expect(find.text('version: $kAppVersion'), findsOneWidget);
    final privacy = tester.widget<Text>(
      find.text('Data hanya tersimpan di ponsel Anda.'),
    );
    expect(privacy.style?.color, PrayerCastColors.mistDeep);
    final version = tester.widget<Text>(find.text('version: $kAppVersion'));
    expect(version.style?.color, PrayerCastColors.mistDeep);
    final homeScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(homeScaffold.backgroundColor, PrayerCastColors.ink);
    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
    expect(find.text('Waktu sholat belum diatur'), findsOneWidget);
    expect(find.text('Singapore, Singapore'), findsNothing);
    expect(find.text('Singapore'), findsNothing);
    expect(find.text('Belum ada speaker'), findsOneWidget);
    expect(find.text('MEMERIKSA RUMAH'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    expect(find.text('Speaker rumah'), findsNothing);
    expect(find.text('PERANGKAT'), findsOneWidget);
    expect(find.text('JADWAL'), findsOneWidget);
    expect(find.text('Waktu sholat'), findsOneWidget);
    expect(find.text('Riwayat pengiriman'), findsNothing);
    expect(find.textContaining('Adzan di rumah'), findsNothing);

    final divider = find.byKey(ColophonFootnote.dividerKey);
    expect(divider, findsOneWidget);
    expect(
      tester.widget<ColoredBox>(divider).color,
      ColophonFootnote.dividerColor,
    );
    expect(tester.getSize(divider).height, 1);
    final prayerBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('home_prayer_times_slab')),
    );
    final dividerTop = tester.getTopLeft(divider);
    final footnoteTop = tester.getTopLeft(
      find.text('Data hanya tersimpan di ponsel Anda.'),
    );
    expect(dividerTop.dy, greaterThan(prayerBottom.dy));
    expect(footnoteTop.dy, greaterThan(dividerTop.dy));
    final homeSize = tester.getSize(find.byType(Scaffold).first);
    expect(
      tester.getBottomLeft(find.text('version: $kAppVersion')).dy,
      greaterThan(homeSize.height * 0.75),
    );

    await tester.tap(find.text('Data hanya tersimpan di ponsel Anda.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Gunakan lokasi saat ini'), findsNothing);

    await tester.tap(find.text('Waktu sholat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Waktu sholat'), findsWidgets);
    expect(find.textContaining('Gunakan lokasi saat ini'), findsOneWidget);
    expect(find.textContaining('Ubah kota / negara'), findsOneWidget);
    expect(find.textContaining('Metode perhitungan'), findsOneWidget);
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
    expect(find.text('Isya'), findsOneWidget);
    expect(find.byKey(AdhanCountdownLabel.keyName), findsOneWidget);
    expect(find.text('sekarang'), findsOneWidget);
    expect(find.text('Singapore, Singapore'), findsNothing);
    expect(find.text('Singapore'), findsNWidgets(2));
  });

  testWidgets('home colophon scrolls on a short phone without overflow', (
    tester,
  ) async {
    await _pumpHomeAtSize(tester, size: const Size(320, 568));
    expect(find.text('PRAYER'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final offstageDivider = find.byKey(
      ColophonFootnote.dividerKey,
      skipOffstage: false,
    );
    expect(offstageDivider, findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.scrollUntilVisible(
      offstageDivider,
      64,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    _expectHairlineImmediatelyAboveFootnotes(tester);

    final scaffoldH = tester.getSize(find.byType(Scaffold).first).height;
    expect(
      tester.getTopLeft(find.byKey(ColophonFootnote.dividerKey)).dy,
      greaterThanOrEqualTo(-1),
    );
    expect(
      tester.getBottomLeft(find.text('version: $kAppVersion')).dy,
      lessThanOrEqualTo(scaffoldH + 1),
    );

    await tester.tap(find.text(_privacyLine));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Gunakan lokasi saat ini'), findsNothing);
  });

  testWidgets('home colophon pins to the bottom on a tall phone', (
    tester,
  ) async {
    await _pumpHomeAtSize(tester, size: const Size(448, 998));
    _expectHairlineImmediatelyAboveFootnotes(tester);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, lessThan(1));

    final scaffoldH = tester.getSize(find.byType(Scaffold).first).height;
    expect(
      scaffoldH - tester.getBottomLeft(find.byType(ColophonFootnote)).dy,
      closeTo(tester.view.padding.bottom, 2),
    );
    expect(
      tester.getBottomLeft(find.text('version: $kAppVersion')).dy,
      greaterThan(scaffoldH * 0.85),
    );

    final prayerBottom = tester.getBottomLeft(find.byKey(_prayerTimesSlab)).dy;
    final dividerTop = tester.getTopLeft(
      find.byKey(ColophonFootnote.dividerKey),
    ).dy;
    expect(dividerTop - prayerBottom, greaterThan(80));
  });
}
