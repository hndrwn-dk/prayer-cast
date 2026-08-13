import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/main.dart';

void main() {
  testWidgets('app shell loads with delivery log entry point', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(PrayerCastAppForTest(database: db));
    // Entrance delays + fade controllers (avoid pumpAndSettle: BreathPulse loops).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Prayer Cast'), findsWidgets);
    expect(find.text('Riwayat pengiriman'), findsOneWidget);

    await tester.tap(find.text('Riwayat pengiriman'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Flush any pending FadeSlideIn delays from the previous route.
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Riwayat pengiriman'), findsWidgets);
    expect(find.textContaining('Belum ada percobaan'), findsOneWidget);
  });
}
