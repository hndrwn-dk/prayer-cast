import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Shown when a home speaker is saved but not visible on the current scan.
class SavedSpeakerOfflineBanner extends StatelessWidget {
  const SavedSpeakerOfflineBanner({
    super.key,
    required this.speakerName,
    this.onRescan,
  });

  static const Key bannerKey = ValueKey('saved_speaker_offline_banner');

  final String speakerName;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    return Material(
      key: bannerKey,
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId ? 'Speaker tersimpan' : 'Saved speaker',
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.surfaceRaised,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              speakerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.displayFont,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PrayerCastColors.dawn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isId
                  ? 'Tidak terdeteksi di WiFi saat ini. Speaker masih tersimpan — pastikan HP dan speaker di jaringan yang sama, lalu pindai ulang.'
                  : 'Not detected on WiFi right now. Your speaker is still saved — make sure phone and speaker share the same network, then scan again.',
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                height: 1.4,
                color: PrayerCastColors.mist,
              ),
            ),
            if (onRescan != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: PrayerCastTheme.minTap,
                child: OutlinedButton(
                  onPressed: onRescan,
                  child: Text(isId ? 'Pindai ulang' : 'Scan again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
