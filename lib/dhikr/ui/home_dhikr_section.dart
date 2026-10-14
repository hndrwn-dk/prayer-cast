import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

class HomeDhikrSection extends ConsumerWidget {
  const HomeDhikrSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final morningEnabled = ref.watch(adhkarEnabledProvider(AdhkarType.morning));
    final eveningEnabled = ref.watch(adhkarEnabledProvider(AdhkarType.evening));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialEyebrow(
            l10n.dhikrSectionTitle.toUpperCase(),
            color: PrayerCastColors.dawn,
          ),
          const SizedBox(height: 12),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DhikrDestinationCell(
                    cellKey: const ValueKey<String>('home_morning_adhkar'),
                    title: l10n.morningAdhkar,
                    subtitle: l10n.afterFajr,
                    enabled: morningEnabled,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MorningAdhkarPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DhikrDestinationCell(
                    cellKey: const ValueKey<String>('home_evening_adhkar'),
                    title: l10n.eveningAdhkar,
                    subtitle: l10n.afterAsr,
                    enabled: eveningEnabled,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EveningAdhkarPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _DhikrDestinationCell(
            cellKey: const ValueKey<String>('home_dhikr_counter'),
            title: l10n.generalDhikr,
            subtitle: l10n.countYourRemembrance,
            enabled: null,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DhikrCounterPage())),
          ),
        ],
      ),
    );
  }
}

class _DhikrDestinationCell extends StatelessWidget {
  const _DhikrDestinationCell({
    required this.cellKey,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final Key cellKey;
  final String title;
  final String subtitle;
  final bool? enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        key: cellKey,
        color: PrayerCastTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.displayFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PrayerCastTokens.onSurface(context),
                        height: 1.3,
                      ),
                    ),
                    if (enabled != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: enabled!
                              ? PrayerCastColors.canopy.withValues(alpha: 0.15)
                              : PrayerCastColors.dawn.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          enabled!
                              ? context.l10n.adhkarEnabled
                              : context.l10n.adhkarDisabled,
                          style: TextStyle(
                            fontFamily: PrayerCastTheme.bodyFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: enabled!
                                ? PrayerCastColors.canopyDeep
                                : PrayerCastTokens.glyphMuted(context),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 13,
                    color: PrayerCastTokens.glyphMuted(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
