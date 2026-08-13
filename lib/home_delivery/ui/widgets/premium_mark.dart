import 'package:flutter/material.dart';

import '../icons/premium_icons.dart';
import '../theme/prayer_cast_colors.dart';

/// Brand mark: speaker + crescent — premium, not a stock icon dump.
class PremiumMark extends StatelessWidget {
  const PremiumMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Prayer Cast',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PrayerCastColors.canopy,
                PrayerCastColors.canopyDeep,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: size * 0.16,
                right: size * 0.16,
                child: PremiumIcons.moon(
                  size: size * 0.22,
                  color: PrayerCastColors.dawnSoft.withValues(alpha: 0.95),
                ),
              ),
              PremiumIcons.speaker(
                size: size * 0.46,
                color: PrayerCastColors.surfaceRaised,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
