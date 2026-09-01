import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_delivery/ui/icons/premium_icons.dart';
import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/widgets/editorial_chrome.dart';
import '../../l10n/l10n_ext.dart';
import '../prayer_tracker_providers.dart';
import '../prayer_tracker_stats.dart';
import '../prayer_tracker_store.dart';
import 'prayer_tracker_stats_page.dart';

/// Daily prayer log — tap timing and where independently per prayer.
class PrayerTrackerPage extends ConsumerStatefulWidget {
  const PrayerTrackerPage({super.key});

  @override
  ConsumerState<PrayerTrackerPage> createState() => _PrayerTrackerPageState();
}

class _PrayerTrackerPageState extends ConsumerState<PrayerTrackerPage> {
  PrayerDayLog? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(todayPrayerLogProvider);
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final dayLabel = _formatToday(isId);
    final title = isId ? 'Catatan sholat' : 'Prayer tracker';
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: ForestScrollScaffold(
        header: EditorialPageHeader(
          eyebrow: dayLabel,
          title: title,
          backTooltip: l10n.back,
          onBack: () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
          trailing: IconButton(
            key: const ValueKey<String>('prayer_tracker_stats_button'),
            tooltip: isId ? 'Jejak ibadah' : 'Your rhythm',
            onPressed: () => _openRhythm(context),
            icon: PremiumIcons.bars(
              size: 22,
              color: PrayerCastColors.mist,
            ),
          ),
        ),
        slivers: [
          log.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('$e')),
            ),
            data: (saved) {
              final draft = _draft ?? saved;
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ReflectionCard(log: draft, isId: isId),
                    const SizedBox(height: 8),
                    _StreakCard(isId: isId),
                    const SizedBox(height: 8),
                    _TodaySummaryCard(log: draft, isId: isId),
                    const SizedBox(height: 16),
                    _DawnTitle(isId ? 'Sholat hari ini' : "Today's prayers"),
                    const SizedBox(height: 10),
                    for (var i = 0; i < kTrackedPrayers.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _PrayerLogCard(
                        prayerId: kTrackedPrayers[i],
                        prayerName: prayerDisplayName(
                          l10n,
                          kTrackedPrayers[i],
                        ),
                        entry: draft[kTrackedPrayers[i]],
                        enabled: !_saving,
                        isId: isId,
                        onTiming: (timing) =>
                            _setTiming(kTrackedPrayers[i], timing, draft),
                        onWhere: (where) =>
                            _setWhere(kTrackedPrayers[i], where, draft),
                        onClear: () =>
                            _clearPrayer(kTrackedPrayers[i], draft),
                      ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openRhythm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrayerTrackerStatsPage(),
      ),
    );
  }

  String _formatToday(bool isId) {
    final now = DateTime.now();
    if (isId) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${now.day} ${months[now.month - 1]} ${now.year}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _setTiming(
    String prayer,
    PrayerLogTiming timing,
    PrayerDayLog current,
  ) {
    final existing = current[prayer] ?? const PrayerLogEntry();
    final nextTiming = existing.timing == timing ? null : timing;
    _updateEntry(
      prayer,
      PrayerLogEntry(timing: nextTiming, where: existing.where),
      current,
    );
  }

  void _setWhere(String prayer, PrayerLogWhere where, PrayerDayLog current) {
    final existing = current[prayer] ?? const PrayerLogEntry();
    final nextWhere = existing.where == where ? null : where;
    _updateEntry(
      prayer,
      PrayerLogEntry(timing: existing.timing, where: nextWhere),
      current,
    );
  }

  void _clearPrayer(String prayer, PrayerDayLog current) {
    final next = Map<String, PrayerLogEntry>.from(current)..remove(prayer);
    setState(() => _draft = next);
    unawaited(_persist(next));
  }

  void _updateEntry(
    String prayer,
    PrayerLogEntry entry,
    PrayerDayLog current,
  ) {
    final next = Map<String, PrayerLogEntry>.from(current);
    if (entry.isEmpty) {
      next.remove(prayer);
    } else {
      next[prayer] = entry;
    }
    setState(() => _draft = next);
    unawaited(_persist(next));
  }

  Future<void> _persist(PrayerDayLog log) async {
    setState(() => _saving = true);
    try {
      final store = ref.read(prayerTrackerStoreProvider);
      final key = FilePrayerTrackerStore.dayKey(DateTime.now());
      await store.writeDay(key, log);
      ref.invalidate(todayPrayerLogProvider);
      ref.invalidate(prayerPeriodStatsProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.log, required this.isId});

  final PrayerDayLog log;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final logged = kTrackedPrayers.where((p) => log[p]?.isLogged ?? false).length;
    var onTime = 0;
    var late = 0;
    var jamaah = 0;
    var alone = 0;
    for (final prayer in kTrackedPrayers) {
      final entry = log[prayer];
      if (entry == null) continue;
      if (entry.timing == PrayerLogTiming.onTime) onTime++;
      if (entry.timing == PrayerLogTiming.late) late++;
      if (entry.where == PrayerLogWhere.jamaah) jamaah++;
      if (entry.where == PrayerLogWhere.alone) alone++;
    }

    final headline = isId
        ? '$logged/5 sholat tercatat'
        : '$logged/5 prayers logged';

    final parts = <String>[];
    if (onTime > 0) {
      parts.add(isId ? '$onTime tepat waktu' : '$onTime on time');
    }
    if (late > 0) {
      parts.add(isId ? '$late terlambat' : '$late late');
    }
    if (jamaah > 0) {
      parts.add(isId ? '$jamaah jamaah' : '$jamaah in mosque');
    }
    if (alone > 0) {
      parts.add(isId ? '$alone sendiri' : '$alone alone');
    }

    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DawnTitle(isId ? 'Ringkasan' : 'Summary'),
            const SizedBox(height: 8),
            Text(headline, style: text.titleMedium),
            const SizedBox(height: 8),
            _ProgressSegments(log: log),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                parts.join(' · '),
                style: text.bodySmall?.copyWith(
                  color: PrayerCastColors.mist,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.log});

  final PrayerDayLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kTrackedPrayers.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 6,
              decoration: BoxDecoration(
                color: (log[kTrackedPrayers[i]]?.isLogged ?? false)
                    ? PrayerCastColors.leaf
                    : PrayerCastColors.inkSoft,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PrayerLogCard extends StatelessWidget {
  const _PrayerLogCard({
    required this.prayerId,
    required this.prayerName,
    required this.entry,
    required this.enabled,
    required this.isId,
    required this.onTiming,
    required this.onWhere,
    required this.onClear,
  });

  final String prayerId;
  final String prayerName;
  final PrayerLogEntry? entry;
  final bool enabled;
  final bool isId;
  final ValueChanged<PrayerLogTiming> onTiming;
  final ValueChanged<PrayerLogWhere> onWhere;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = entry;

    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KeyedSubtree(
                  key: ValueKey<String>('prayer-icon-$prayerId'),
                  child: PremiumIcons.forPrayer(
                    prayerId,
                    size: 22,
                    color: PrayerCastColors.dawn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    prayerName,
                    style: text.titleMedium?.copyWith(fontSize: 16),
                  ),
                ),
                if (e?.isLogged ?? false)
                  IconButton(
                    tooltip: isId ? 'Hapus' : 'Clear',
                    onPressed: enabled ? onClear : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: PrayerCastColors.mist,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _SegmentedPair(
                    leftLabel: isId ? 'Tepat' : 'On time',
                    rightLabel: isId ? 'Telat' : 'Late',
                    leftSelected: e?.timing == PrayerLogTiming.onTime,
                    rightSelected: e?.timing == PrayerLogTiming.late,
                    enabled: enabled,
                    onLeft: () => onTiming(PrayerLogTiming.onTime),
                    onRight: () => onTiming(PrayerLogTiming.late),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentedPair(
                    leftLabel: isId ? 'Sendiri' : 'Alone',
                    rightLabel: isId ? 'Jamaah' : 'Mosque',
                    leftSelected: e?.where == PrayerLogWhere.alone,
                    rightSelected: e?.where == PrayerLogWhere.jamaah,
                    enabled: enabled,
                    onLeft: () => onWhere(PrayerLogWhere.alone),
                    onRight: () => onWhere(PrayerLogWhere.jamaah),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedPair extends StatelessWidget {
  const _SegmentedPair({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.rightSelected,
    required this.enabled,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final bool rightSelected;
  final bool enabled;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PrayerCastColors.ink.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: leftLabel,
                selected: leftSelected,
                enabled: enabled,
                onTap: onLeft,
              ),
            ),
            Expanded(
              child: _Segment(
                label: rightLabel,
                selected: rightSelected,
                enabled: enabled,
                onTap: onRight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PrayerCastColors.leaf : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 11,
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

const _reflectionTipsId = [
  'Menjaga Subuh tepat waktu termasuk amal yang paling berat di timbangan.',
  'Amal yang paling dicintai adalah yang dikerjakan dengan istiqamah.',
  'Sholat berjamaah lebih utama daripada sendirian.',
  'Tepat waktu lebih dicintai daripada yang diqadha kemudian.',
  'Mulai dengan Bismillah, tutup dengan Alhamdulillah.',
];

const _reflectionTipsEn = [
  'Maintaining Fajr on time is among the heaviest deeds on the scale.',
  'The most beloved deeds are those done consistently.',
  'Prayer in congregation carries more reward than praying alone.',
  'A prayer on time is more beloved than one made up later.',
  'Begin with Bismillah; close with Alhamdulillah.',
];

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.log, required this.isId});

  final PrayerDayLog log;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final logged =
        kTrackedPrayers.where((p) => log[p]?.isLogged ?? false).length;
    final remaining = kTrackedPrayers.length - logged;
    final complete = remaining == 0;
    final headline = complete
        ? (isId
            ? 'Alhamdulillah — 5 sholat hari ini sudah tercatat.'
            : 'Alhamdulillah — all 5 prayers logged today.')
        : (isId
            ? 'Sisa $remaining sholat yang belum tercatat hari ini.'
            : '$remaining prayers left to log today.');
    final tips = isId ? _reflectionTipsId : _reflectionTipsEn;
    final now = DateTime.now();
    final tip = tips[now.difference(DateTime(now.year)).inDays % tips.length];

    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DawnTitle(isId ? 'Renungan' : 'Reflection'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: complete
                      ? PremiumIcons.check(
                          size: 18,
                          color: PrayerCastColors.leaf,
                        )
                      : PremiumIcons.moon(
                          size: 18,
                          color: PrayerCastColors.dawn,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: text.bodySmall?.copyWith(
                      color: PrayerCastColors.mist,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tip,
              style: text.bodySmall?.copyWith(
                color: PrayerCastColors.mistDeep,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.isId});

  final bool isId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final streak =
        ref.watch(prayerPeriodStatsProvider).valueOrNull?.streakDays ?? 0;
    final young = streak <= 1;
    final subtitle = young
        ? (isId
            ? 'Catat besok untuk mulai rantai.'
            : 'Log tomorrow to start a streak.')
        : (isId ? 'hari rantai' : 'day streak');

    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DawnTitle(isId ? 'Rantai' : 'Streak'),
            const SizedBox(height: 8),
            Row(
              children: [
                PremiumIcons.flame(
                  size: 28,
                  color: young ? PrayerCastColors.mist : PrayerCastColors.dawn,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak',
                        key: const ValueKey<String>('prayer_tracker_streak_value'),
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: PrayerCastColors.mist,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DawnTitle extends StatelessWidget {
  const _DawnTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: PrayerCastColors.dawn,
          ),
    );
  }
}
