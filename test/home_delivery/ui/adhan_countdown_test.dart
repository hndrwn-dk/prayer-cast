import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/adhan_countdown.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/l10n/app_localizations_en.dart';
import 'package:prayer_cast/l10n/app_localizations_id.dart';

void main() {
  group('AdhanCountdown.remaining', () {
    test(
      'uses whole minutes so seconds on the clock do not change the count',
      () {
        final adhan = DateTime(2026, 9, 28, 18, 58);
        expect(
          AdhanCountdown.remaining(adhan, DateTime(2026, 9, 28, 18, 41, 36)),
          const Duration(minutes: 17),
        );
        expect(
          AdhanCountdown.remaining(adhan, DateTime(2026, 9, 28, 18, 41)),
          const Duration(minutes: 17),
        );
      },
    );

    test('Isha 20:07 from 20:01 is 6 minutes, not a seconds clock', () {
      expect(
        AdhanCountdown.remaining(
          DateTime(2026, 9, 28, 20, 7),
          DateTime(2026, 9, 28, 20, 1, 15),
        ),
        const Duration(minutes: 6),
      );
    });

    test('same displayed minute is due', () {
      final remaining = AdhanCountdown.remaining(
        DateTime(2026, 9, 28, 18, 58),
        DateTime(2026, 9, 28, 18, 58, 40),
      );
      expect(remaining, Duration.zero);
      expect(AdhanCountdown.isDue(remaining), isTrue);
    });

    test('past the prayer minute is due', () {
      expect(
        AdhanCountdown.isDue(
          AdhanCountdown.remaining(
            DateTime(2026, 9, 28, 18, 58),
            DateTime(2026, 9, 28, 18, 59),
          ),
        ),
        isTrue,
      );
    });
  });

  group('AdhanCountdown.durationLabel', () {
    final en = AppLocalizationsEn();
    final id = AppLocalizationsId();

    test('formats minutes without seconds', () {
      expect(
        AdhanCountdown.durationLabel(const Duration(minutes: 17), en),
        '17 min',
      );
      expect(
        AdhanCountdown.durationLabel(const Duration(minutes: 17), id),
        '17 menit',
      );
    });

    test('formats hours and leftover minutes', () {
      expect(
        AdhanCountdown.durationLabel(const Duration(hours: 2, minutes: 5), en),
        '2 hr 5 min',
      );
      expect(
        AdhanCountdown.durationLabel(const Duration(hours: 1), en),
        '1 hr',
      );
      expect(
        AdhanCountdown.durationLabel(const Duration(hours: 2, minutes: 5), id),
        '2 jam 5 menit',
      );
    });
  });

  testWidgets('home label shows minute countdown, not MM:SS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.forest(),
        home: Scaffold(
          body: AdhanCountdownLabel(
            scheduledAt: DateTime(2026, 9, 28, 18, 58),
            prayerName: 'Maghrib',
            now: () => DateTime(2026, 9, 28, 18, 41, 36),
          ),
        ),
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(find.byKey(AdhanCountdownLabel.keyName));
    final shown = label.textSpan!.toPlainText();
    expect(shown.contains('16:24'), isFalse);
    expect(shown, 'Maghrib in 17 min');
  });
}
