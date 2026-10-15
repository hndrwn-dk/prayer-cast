import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/data/dhikr_catalog.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_focus_page.dart';
import 'package:prayer_cast/dhikr/ui/widgets/counter_progress.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Entry to the counters. Counting itself happens in [DhikrFocusPage]:
/// this page only picks what to count and shows where each count stands.
class DhikrCounterPage extends ConsumerWidget {
  const DhikrCounterPage({super.key});

  static const ValueKey<String> listKey =
      ValueKey<String>('dhikr_counter_page');
  static const ValueKey<String> afterPrayerKey =
      ValueKey<String>('dhikr_after_prayer');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final afterPrayer = DhikrCatalog.afterPrayer(l10n);
    final free = DhikrCatalog.free(l10n);

    Future<void> open(List<DhikrSpec> steps, {required bool sequence}) async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DhikrFocusPage(
            steps: steps,
            sequence: sequence,
            eyebrow: sequence ? l10n.dhikrAfterPrayerTitle : l10n.dhikrFreeTitle,
          ),
        ),
      );
      for (final s in steps) {
        ref.invalidate(dhikrCounterProvider(s.id));
      }
    }

    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.dhikrSectionTitle,
        title: l10n.generalDhikr,
        backTooltip: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        key: listKey,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          InkSurface(
            key: afterPrayerKey,
            borderColor: PrayerCastTokens.hairline(context),
            onTap: () => open(afterPrayer, sequence: true),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EditorialEyebrow(
                        l10n.dhikrAfterPrayerTitle,
                        color: PrayerCastColors.dawn,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${afterPrayer[0].arabic} · ${afterPrayer[1].arabic} · ${afterPrayer[2].arabic}',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.7,
                          color: PrayerCastTokens.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.dhikrAfterPrayerSubtitle,
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.bodyFont,
                          fontSize: 14,
                          height: 1.4,
                          color: PrayerCastTokens.glyphMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: PrayerCastTokens.glyph(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          EditorialEyebrow(l10n.dhikrFreeTitle, color: PrayerCastColors.dawn),
          const SizedBox(height: 4),
          Text(
            l10n.dhikrFreeSubtitle,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 14,
              color: PrayerCastTokens.glyphMuted(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final spec in free) ...[
            _FreeDhikrTile(
              spec: spec,
              onTap: () => open([spec], sequence: false),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FreeDhikrTile extends ConsumerWidget {
  const _FreeDhikrTile({required this.spec, required this.onTap});

  final DhikrSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(dhikrCounterProvider(spec.id)).valueOrNull?.count ?? 0;
    final progress =
        spec.target == 0 ? 0.0 : (count / spec.target).clamp(0.0, 1.0).toDouble();

    return Semantics(
      button: true,
      label: '${spec.translation}, $count / ${spec.target}',
      excludeSemantics: true,
      child: InkSurface(
        borderColor: PrayerCastTokens.hairline(context),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.arabic,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.6,
                          color: PrayerCastTokens.onSurface(context),
                        ),
                      ),
                      Text(
                        spec.translation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.bodyFont,
                          fontSize: 13,
                          color: PrayerCastTokens.glyphMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$count',
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.displayFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: PrayerCastTokens.onSurface(context),
                        ),
                      ),
                      TextSpan(
                        text: '/${spec.target}',
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.bodyFont,
                          fontSize: 14,
                          color: PrayerCastTokens.glyphMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (count > 0) ...[
              const SizedBox(height: 10),
              CounterProgress(progress: progress),
            ],
          ],
        ),
      ),
    );
  }
}
