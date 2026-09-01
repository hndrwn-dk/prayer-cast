import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Prompt to open battery-unrestricted settings when optimisation is on.
class OemBatteryBanner extends StatelessWidget {
  const OemBatteryBanner({super.key, required this.onOpen});

  static const Key bannerKey = ValueKey('oem_battery_banner');
  static const Key openKey = ValueKey('oem_battery_open');

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: bannerKey,
      color: PrayerCastColors.dawnSoft,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(context),
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _body(context),
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                height: 1.4,
                color: PrayerCastColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                key: openKey,
                onPressed: onOpen,
                child: Text(_button(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _title(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'id'
        ? 'Batasi penghemat baterai'
        : 'Disable battery restrictions';
  }

  static String _body(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'id'
        ? 'Agar alarm sholat dan adzan tetap jalan saat HP tidur, set Prayer Cast ke Tanpa batasan / Unrestricted di pengaturan baterai.'
        : 'So prayer alarms and adhan still fire while the phone sleeps, set Prayer Cast to Unrestricted in battery settings.';
  }

  static String _button(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'id'
        ? 'Buka pengaturan baterai'
        : 'Open battery settings';
  }
}
