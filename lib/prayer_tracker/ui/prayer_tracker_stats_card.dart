import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_delivery/ui/icons/premium_icons.dart';
import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../l10n/l10n_ext.dart';
import '../prayer_tracker_providers.dart';
import '../prayer_tracker_stats.dart';

class PrayerTrackerStatsCard extends ConsumerWidget {
  const PrayerTrackerStatsCard({super.key, required this.isId});

  final bool isId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(prayerStatsPeriodProvider);
    final stats = ref.watch(prayerPeriodStatsProvider);
    final text = Theme.of(context).textTheme;

    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId ? 'Jejak ibadah' : 'Your rhythm',
              style: text.labelLarge?.copyWith(color: PrayerCastColors.dawn),
            ),
            const SizedBox(height: 10),
            _PeriodToggle(
              period: period,
              isId: isId,
              onChanged: (next) {
                ref.read(prayerStatsPeriodProvider.notifier).state = next;
              },
            ),
            const SizedBox(height: 16),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e', style: text.bodySmall),
              data: (value) => _StatsBody(stats: value, isId: isId),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.isId,
    required this.onChanged,
  });

  final PrayerStatsPeriod period;
  final bool isId;
  final ValueChanged<PrayerStatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in PrayerStatsPeriod.values) ...[
          if (entry != PrayerStatsPeriod.values.first) const SizedBox(width: 6),
          Expanded(
            child: _PeriodChip(
              label: _label(entry, isId),
              selected: period == entry,
              onTap: () => onChanged(entry),
            ),
          ),
        ],
      ],
    );
  }

  static String _label(PrayerStatsPeriod period, bool isId) {
    if (isId) {
      return switch (period) {
        PrayerStatsPeriod.week => '7 hari',
        PrayerStatsPeriod.month => '30 hari',
        PrayerStatsPeriod.year => 'Tahun ini',
      };
    }
    return switch (period) {
      PrayerStatsPeriod.week => '7 days',
      PrayerStatsPeriod.month => '30 days',
      PrayerStatsPeriod.year => 'This year',
    };
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PrayerCastColors.leaf.withValues(alpha: 0.35)
          : PrayerCastColors.inkSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 13,
              color: selected
                  ? PrayerCastColors.surfaceRaised
                  : PrayerCastColors.mist,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.isId});

  final PrayerPeriodStats stats;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _HeroMetric(
                value: '${stats.completionPercent}%',
                label: isId
                    ? '${stats.loggedSlots}/${stats.possibleSlots} tercatat'
                    : '${stats.loggedSlots}/${stats.possibleSlots} logged',
              ),
            ),
            _HeroMetric(
              value: '${stats.streakDays}',
              label: isId ? 'hari rantai' : 'day streak',
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (stats.period == PrayerStatsPeriod.year)
          _YearBars(months: stats.months, isId: isId)
        else
          _HeatStrip(pulses: stats.pulses, isId: isId),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _RateTile(
                label: isId ? 'Tepat waktu' : 'On time',
                value: stats.timedSlots == 0 ? '--' : '${stats.onTimePercent}%',
                detail: stats.timedSlots == 0
                    ? (isId ? 'belum ada' : 'none yet')
                    : '${stats.onTime}/${stats.timedSlots}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RateTile(
                label: isId ? 'Jamaah' : 'In mosque',
                value: stats.placedSlots == 0 ? '--' : '${stats.jamaahPercent}%',
                detail: stats.placedSlots == 0
                    ? (isId ? 'belum ada' : 'none yet')
                    : '${stats.jamaah}/${stats.placedSlots}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RateTile(
                label: isId ? 'Hari penuh' : 'Full days',
                value: '${stats.daysComplete}',
                detail: isId
                    ? '${stats.daysLogged} hari tercatat'
                    : '${stats.daysLogged} days logged',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isId ? 'Per sholat' : 'By prayer',
          style: text.labelMedium?.copyWith(color: PrayerCastColors.mist),
        ),
        const SizedBox(height: 8),
        for (final prayer in kTrackedPrayers)
          _PrayerBar(
            name: prayerDisplayName(
              context.l10n,
              prayer,
            ),
            logged: stats.loggedByPrayer[prayer] ?? 0,
            possible: stats.elapsedDays,
          ),
      ],
    );
  }
}

class PrayerTrackerInsights extends ConsumerWidget {
  const PrayerTrackerInsights({super.key, required this.isId});

  final bool isId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(prayerPeriodStatsProvider);
    return stats.maybeWhen(
      data: (value) => _InsightsBody(insights: value.observations(isId: isId), isId: isId),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.insights, required this.isId});

  final List<PrayerStatInsight> insights;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isId ? 'Wawasan' : 'Insights',
          style: text.labelLarge?.copyWith(color: PrayerCastColors.dawn),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < insights.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _InsightCard(insight: insights[i]),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final PrayerStatInsight insight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: insight.positive
                  ? PremiumIcons.trendUp(
                      size: 20,
                      color: PrayerCastColors.leaf,
                    )
                  : PremiumIcons.alertCircle(
                      size: 20,
                      color: PrayerCastColors.dawn,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insight.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PrayerCastColors.mist,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: PrayerCastColors.surfaceRaised,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PrayerCastColors.mist,
              ),
        ),
      ],
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: PrayerCastColors.ink.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelSmall?.copyWith(color: PrayerCastColors.mist),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              color: PrayerCastColors.surfaceRaised,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: text.bodySmall?.copyWith(
              color: PrayerCastColors.mistDeep,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatStrip extends StatelessWidget {
  const _HeatStrip({required this.pulses, required this.isId});

  final List<PrayerDayPulse> pulses;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    final monthGrid = pulses.length > 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isId ? 'Peta 5 sholat / hari' : 'Map of 5 prayers / day',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: PrayerCastColors.mist,
              ),
        ),
        const SizedBox(height: 8),
        if (monthGrid)
          GridView.builder(
            key: const ValueKey<String>('prayer_heat_grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pulses.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) => _HeatCell(pulse: pulses[i]),
          )
        else
          Row(
            key: const ValueKey<String>('prayer_heat_row'),
            children: [
              for (var i = 0; i < pulses.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: _HeatCell(pulse: pulses[i]),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 6),
        Text(
          isId
              ? 'Kosong = belum tercatat. Penuh = 5/5.'
              : 'Empty = not logged. Solid = 5/5.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PrayerCastColors.mist,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.pulse});

  final PrayerDayPulse pulse;

  @override
  Widget build(BuildContext context) {
    final empty = pulse.loggedCount <= 0;
    return Tooltip(
      message: '${pulse.day.month}/${pulse.day.day} · ${pulse.loggedCount}/5',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: empty
              ? PrayerCastColors.ink.withValues(alpha: 0.4)
              : _heatColor(pulse.loggedCount),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: empty
                ? PrayerCastColors.mistDeep.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _YearBars extends StatelessWidget {
  const _YearBars({required this.months, required this.isId});

  final List<PrayerMonthBucket> months;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    const namesId = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const namesEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final names = isId ? namesId : namesEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isId ? 'Isi per bulan' : 'Fill by month',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: PrayerCastColors.mist,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _MonthBar(
                    bucket: months[i],
                    label: names[months[i].month - 1],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.bucket, required this.label});

  final PrayerMonthBucket bucket;
  final String label;

  @override
  Widget build(BuildContext context) {
    final empty = bucket.loggedSlots <= 0;
    final t = bucket.possibleSlots == 0
        ? 0.0
        : bucket.loggedSlots / bucket.possibleSlots;
    final height = empty ? 0.16 : t.clamp(0.16, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: height,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: empty
                      ? PrayerCastColors.ink.withValues(alpha: 0.35)
                      : _heatColor((t * 5).round().clamp(1, 5)),
                  borderRadius: BorderRadius.circular(3),
                  border: empty
                      ? Border.all(
                          color: PrayerCastColors.mistDeep.withValues(
                            alpha: 0.45,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: PrayerCastColors.mistDeep,
                fontSize: 9,
              ),
        ),
      ],
    );
  }
}

class _PrayerBar extends StatelessWidget {
  const _PrayerBar({
    required this.name,
    required this.logged,
    required this.possible,
  });

  final String name;
  final int logged;
  final int possible;

  @override
  Widget build(BuildContext context) {
    final t = possible == 0 ? 0.0 : logged / possible;
    final fill = logged <= 0 ? 0.0 : t.clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PrayerCastColors.mist,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: PrayerCastColors.inkSoft,
                      child: SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: fill,
                      child: const ColoredBox(
                        color: PrayerCastColors.leaf,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              '$logged/$possible',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PrayerCastColors.mistDeep,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _heatColor(int loggedCount) {
  return switch (loggedCount) {
    0 => PrayerCastColors.inkSoft,
    1 => PrayerCastColors.leaf.withValues(alpha: 0.28),
    2 => PrayerCastColors.leaf.withValues(alpha: 0.48),
    3 => PrayerCastColors.leaf.withValues(alpha: 0.68),
    4 => PrayerCastColors.leaf.withValues(alpha: 0.85),
    _ => PrayerCastColors.leaf,
  };
}
