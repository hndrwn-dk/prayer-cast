import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';
import '../theme/prayer_cast_tokens.dart';
import 'editorial_chrome.dart';

/// Top store-frame caption. Mount only while capturing Play screenshots
/// so the navigation bar stays clear.
class PlayStoreCaptionBar extends StatelessWidget {
  const PlayStoreCaptionBar({super.key, required this.text});

  static const panelKey = ValueKey<String>('play_store_caption_panel');
  static const paddingKey = ValueKey<String>('play_store_caption_padding');

  final String text;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final fill = light
        ? PrayerCastTokens.surface(context)
        : PrayerCastColors.canopyDeep;
    final ink = PrayerCastTokens.onSurface(context);

    return Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        key: panelKey,
        decoration: BoxDecoration(color: fill),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            key: paddingKey,
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: ink,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: PrayerCastTheme.displayFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: ink,
                      fontVariations: const [FontVariation('wght', 500)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const EditorialHairline(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
