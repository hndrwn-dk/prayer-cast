import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Quiet Home one-liner under the next-adhan chip. Tap opens the full card.
class SpiritualBenefitsTeaserLine extends StatelessWidget {
  const SpiritualBenefitsTeaserLine({
    super.key,
    required this.prayerKey,
    required this.onTap,
  });

  final String prayerKey;
  final VoidCallback onTap;

  static const ValueKey<String> keyName = ValueKey<String>(
    'home_spiritual_benefits_teaser',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final copy = SpiritualBenefits.of(l10n, prayerKey);
    if (copy == null) return const SizedBox.shrink();
    final label = l10n.spiritualBenefitsTeaser(
      prayerDisplayName(l10n, copy.prayerKey),
      copy.teaser,
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: keyName,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 13,
                height: 1.35,
                color: PrayerCastColors.mistDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
