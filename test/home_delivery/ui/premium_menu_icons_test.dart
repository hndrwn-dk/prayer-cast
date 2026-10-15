import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';

void main() {
  testWidgets('home menu icons render at 34 px', (tester) async {
    final icons = <Widget>[
      PremiumIcons.prayerTimes(size: 34, color: PrayerCastColors.canopy),
      PremiumIcons.prayerTracker(size: 34, color: PrayerCastColors.canopy),
      PremiumIcons.qibla(size: 34, color: PrayerCastColors.canopy),
      PremiumIcons.morningAdhkar(size: 34, color: PrayerCastColors.canopy),
      PremiumIcons.eveningAdhkar(size: 34, color: PrayerCastColors.canopy),
      PremiumIcons.tasbih(size: 34, color: PrayerCastColors.canopy),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Column(key: const Key('menu-icons'), children: icons),
      ),
    );

    expect(tester.takeException(), isNull);
    final paints = find.descendant(
      of: find.byKey(const Key('menu-icons')),
      matching: find.byType(CustomPaint),
    );
    expect(paints, findsNWidgets(icons.length));
    for (var i = 0; i < icons.length; i++) {
      expect(tester.getSize(paints.at(i)), const Size(34, 34));
    }
  });
}
