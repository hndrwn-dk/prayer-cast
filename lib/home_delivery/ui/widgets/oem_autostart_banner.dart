import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// First-run / Cast-setup prompt for ColorOS Auto-launch and kin.
class OemAutostartBanner extends StatelessWidget {
  const OemAutostartBanner({super.key, required this.onOpen});

  static const Key bannerKey = ValueKey('oem_autostart_banner');
  static const Key openKey = ValueKey('oem_autostart_open');

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              l10n.oemAutostartTitle,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.oemAutostartBody,
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
                child: Text(l10n.oemAutostartOpenSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
