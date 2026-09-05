import 'package:flutter/material.dart';

import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/widgets/editorial_chrome.dart';
import '../../l10n/l10n_ext.dart';
import 'prayer_tracker_stats_card.dart';

/// Period stats for the daily log — opened from Catatan sholat, not stacked on it.
class PrayerTrackerStatsPage extends StatelessWidget {
  const PrayerTrackerStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    return Theme(
      data: PrayerCastTheme.forest(),
      child: ForestScrollScaffold(
        header: EditorialPageHeader(
          eyebrow: isId ? 'Ibadah' : 'Worship',
          title: isId ? 'Jejak ibadah' : 'Your rhythm',
          backTooltip: context.l10n.back,
          onBack: () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                PrayerTrackerInsights(isId: isId),
                const SizedBox(height: 16),
                PrayerTrackerStatsCard(isId: isId),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
