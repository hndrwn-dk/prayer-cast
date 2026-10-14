import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/models/dhikr_counter_state.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/dhikr/ui/widgets/counter_cell.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

typedef _DhikrSpec = ({
  String id,
  String Function(AppLocalizations) arabic,
  String Function(AppLocalizations) translation,
  int target,
});

final List<_DhikrSpec> _dhikrSpecs = [
  (
    id: 'subhanallah',
    arabic: (l) => l.dhikrSubhanallahArabic,
    translation: (l) => l.dhikrSubhanallahTranslation,
    target: 33,
  ),
  (
    id: 'alhamdulillah',
    arabic: (l) => l.dhikrAlhamdulillahArabic,
    translation: (l) => l.dhikrAlhamdulillahTranslation,
    target: 33,
  ),
  (
    id: 'allahu-akbar',
    arabic: (l) => l.dhikrAllahuAkbarArabic,
    translation: (l) => l.dhikrAllahuAkbarTranslation,
    target: 34,
  ),
  (
    id: 'la-ilaha-illallah',
    arabic: (l) => l.dhikrLaIlahaIllallahArabic,
    translation: (l) => l.dhikrLaIlahaIllallahTranslation,
    target: 25,
  ),
  (
    id: 'subhanallah-wabihamdihi',
    arabic: (l) => l.dhikrSubhanallahWabihamdihiArabic,
    translation: (l) => l.dhikrSubhanallahWabihamdihiTranslation,
    target: 100,
  ),
  (
    id: 'subhanallah-wabihamdihi-adzim',
    arabic: (l) => l.dhikrSubhanallahWabihamdihiAdzimArabic,
    translation: (l) => l.dhikrSubhanallahWabihamdihiAdzimTranslation,
    target: 100,
  ),
  (
    id: 'astaghfirullah',
    arabic: (l) => l.dhikrAstaghfirullahArabic,
    translation: (l) => l.dhikrAstaghfirullahTranslation,
    target: 100,
  ),
];

/// Dhikr counter page with interactive counters for common dhikr.
class DhikrCounterPage extends ConsumerWidget {
  const DhikrCounterPage({super.key});

  static const ValueKey<String> listKey =
      ValueKey<String>('dhikr_counter_page');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.dhikrSectionTitle,
        title: l10n.generalDhikr,
        backTooltip: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView.separated(
        key: listKey,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        itemCount: _dhikrSpecs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final spec = _dhikrSpecs[i];
          return _DhikrCounterItem(
            dhikrId: spec.id,
            arabic: spec.arabic(l10n),
            translation: spec.translation(l10n),
            target: spec.target,
          );
        },
      ),
    );
  }
}

class _DhikrCounterItem extends ConsumerWidget {
  const _DhikrCounterItem({
    required this.dhikrId,
    required this.arabic,
    required this.translation,
    required this.target,
  });

  final String dhikrId;
  final String arabic;
  final String translation;
  final int target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterAsync = ref.watch(dhikrCounterProvider(dhikrId));
    final state = counterAsync.valueOrNull ??
        DhikrCounterState(dhikrId: dhikrId, count: 0, target: target);

    return CounterCell(
      state: state,
      arabic: arabic,
      translation: translation,
      resetLabel: context.l10n.dhikrReset,
      onTap: () => incrementDhikrCounter(ref, dhikrId, target),
      onReset: () => resetDhikrCounter(ref, dhikrId),
    );
  }
}
