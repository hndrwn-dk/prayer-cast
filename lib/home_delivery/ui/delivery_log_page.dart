import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../coordinator/prayer_delivery_coordinator.dart';
import '../logging/delivery_database.dart';
import '../logging/delivery_retry_window.dart';
import '../logging/outcome.dart';
import '../logging/outcome_explanation.dart';
import '../platform/oem_battery_settings.dart';
import 'delivery_log_providers.dart';
import 'icons/premium_icons.dart';
import 'outcome_status.dart';
import 'theme/atmosphere_background.dart';
import 'theme/prayer_cast_colors.dart';
import 'theme/prayer_cast_theme.dart';
import 'widgets/editorial_chrome.dart';

/// Local-only delivery attempt history (spec §6.3).
class DeliveryLogPage extends ConsumerStatefulWidget {
  const DeliveryLogPage({
    super.key,
    this.coordinator,
  });

  final PrayerDeliveryCoordinator? coordinator;

  @override
  ConsumerState<DeliveryLogPage> createState() => _DeliveryLogPageState();
}

enum _LogFilter { all, failedOnly }

class _DeliveryLogPageState extends ConsumerState<DeliveryLogPage> {
  _LogFilter _filter = _LogFilter.all;
  int? _retryingId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = ref.watch(deliveryLogLatestProvider);
    final missed = ref.watch(failedAlarmMissedWeekProvider);
    final locale = Localizations.localeOf(context);
    final isId = locale.languageCode == 'id';

    return Theme(
      data: PrayerCastTheme.forest(),
      child: Builder(
        builder: (context) {
          return ForestScaffold(
            header: EditorialPageHeader(
              title: l10n.deliveryLog,
              backTooltip: l10n.back,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    l10n.deliveryLogPageIntro,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SegmentedButton<_LogFilter>(
                    segments: [
                      ButtonSegment(
                        value: _LogFilter.all,
                        label: Text(isId ? 'Semua' : 'All'),
                      ),
                      ButtonSegment(
                        value: _LogFilter.failedOnly,
                        label: Text(isId ? 'Gagal saja' : 'Failed only'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selected) {
                      setState(() => _filter = selected.first);
                    },
                  ),
                ),
                missed.when(
                  data: (count) {
                    if (!shouldShowOemBatteryNudge(count)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _OemBatteryBanner(
                        count: count,
                        isId: isId,
                        onOpen: () async {
                          final opened = await ref
                              .read(oemBatterySettingsProvider)
                              .open();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? (isId
                                          ? 'Membuka pengaturan baterai…'
                                          : 'Opening battery settings…')
                                    : (isId
                                          ? 'Tidak bisa membuka pengaturan baterai.'
                                          : 'Could not open battery settings.'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                Expanded(
                  child: rows.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: PrayerCastColors.leaf,
                        ),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isId
                              ? 'Gagal memuat riwayat.\n$e'
                              : 'Could not load the log.\n$e',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    data: (list) {
                      final visible = _filter == _LogFilter.all
                          ? list
                          : list
                              .where((row) {
                                final kind =
                                    OutcomeStatus.of(Outcome.fromCode(row.outcome))
                                        .kind;
                                return kind == OutcomeKind.problem;
                              })
                              .toList();
                      if (visible.isEmpty) {
                        return FadeSlideIn(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PremiumIcons.clock(
                                    size: 56,
                                    color: PrayerCastColors.mist,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isId
                                        ? 'Belum ada percobaan pengiriman.'
                                        : 'No delivery attempts yet.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isId
                                        ? 'Riwayat muncul setelah alarm Adhan pertama berjalan.'
                                        : 'The log appears after the first Adhan alarm runs.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final row = visible[index];
                          final outcome = Outcome.fromCode(row.outcome);
                          final status = OutcomeStatus.of(outcome);
                          return FadeSlideIn(
                            delay: Duration(
                              milliseconds: 40 * index.clamp(0, 8),
                            ),
                            child: status.kind == OutcomeKind.problem
                                ? _FailureAttemptCard(
                                    row: row,
                                    locale: locale,
                                    retrying: _retryingId == row.id,
                                    onRetry: widget.coordinator == null
                                        ? null
                                        : () => _retry(row),
                                  )
                                : _SuccessAttemptLine(
                                    row: row,
                                    locale: locale,
                                  ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _retry(DeliveryLog row) async {
    final coordinator = widget.coordinator;
    if (coordinator == null) return;
    setState(() => _retryingId = row.id);
    final ok = await coordinator.retryFailedAttempt(
      prayer: row.prayer,
      scheduledAtMs: row.scheduledAt,
      firedAtMs: row.firedAt,
    );
    if (!mounted) return;
    setState(() => _retryingId = null);
    ref.invalidate(deliveryLogLatestProvider);
    final isId = Localizations.localeOf(context).languageCode == 'id';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (isId ? 'Mencoba ulang…' : 'Retrying…')
              : (isId
                    ? 'Jendela waktu sholat sudah lewat'
                    : 'Prayer window has ended'),
        ),
      ),
    );
  }
}

class _OemBatteryBanner extends StatelessWidget {
  const _OemBatteryBanner({
    required this.count,
    required this.isId,
    required this.onOpen,
  });

  final int count;
  final bool isId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final openLabel = isId
        ? 'Buka pengaturan baterai'
        : 'Open battery settings';
    return Semantics(
      button: true,
      label: openLabel,
      child: InkSurface(
        color: PrayerCastColors.canopyDeep,
        borderColor: PrayerCastColors.dawn,
        borderWidth: PrayerCastTheme.cardHairline,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PremiumIcons.batteryWarning(
                  size: 28,
                  color: PrayerCastColors.dawn,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isId
                        ? 'Alarm terlambat $count kali minggu ini'
                        : 'Alarm late $count times this week',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isId
                  ? 'Izinkan Prayer Cast berjalan di latar lewat pengaturan baterai ponsel Anda (Xiaomi, Oppo, Vivo, Samsung).'
                  : 'Allow Prayer Cast to run in the background in your phone battery settings (Xiaomi, Oppo, Vivo, Samsung).',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                onPressed: onOpen,
                child: Text(openLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _historyDateLabel(DateTime when, Locale locale) {
  final isId = locale.languageCode == 'id';
  const daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const daysId = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  const monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const monthsId = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final day = (isId ? daysId : daysEn)[(when.weekday - 1).clamp(0, 6)];
  final month = (isId ? monthsId : monthsEn)[(when.month - 1).clamp(0, 11)];
  final hh = when.hour.toString().padLeft(2, '0');
  final mm = when.minute.toString().padLeft(2, '0');
  return '$day, ${when.day} $month · $hh:$mm';
}

String _prayerLabel(String prayer) {
  if (prayer.isEmpty) return prayer;
  return prayer[0].toUpperCase() + prayer.substring(1);
}

String _deviceLabel(DeliveryLog row, {required bool isId}) {
  final name = row.targetName?.trim();
  if (name != null && name.isNotEmpty) {
    if (name == 'phone') return isId ? 'Ponsel' : 'Phone';
    return name;
  }
  if (row.role == 'LOCAL') return isId ? 'Ponsel' : 'Phone';
  return isId ? 'Speaker' : 'Speaker';
}

class _SuccessAttemptLine extends StatelessWidget {
  const _SuccessAttemptLine({
    required this.row,
    required this.locale,
  });

  final DeliveryLog row;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final outcome = Outcome.fromCode(row.outcome);
    final status = OutcomeStatus.of(outcome);
    final when = DateTime.fromMillisecondsSinceEpoch(row.scheduledAt).toLocal();
    final isId = locale.languageCode == 'id';
    final line =
        '${_prayerLabel(row.prayer)} · ${_historyDateLabel(when, locale)} · '
        '${_deviceLabel(row, isId: isId)} · ${status.shortLabel(locale)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: line,
        child: Text(
          line,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _FailureAttemptCard extends StatelessWidget {
  const _FailureAttemptCard({
    required this.row,
    required this.locale,
    required this.retrying,
    required this.onRetry,
  });

  final DeliveryLog row;
  final Locale locale;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final outcome = Outcome.fromCode(row.outcome);
    final status = OutcomeStatus.of(outcome);
    final explanation = OutcomeExplanation.forOutcome(outcome, locale);
    final when = DateTime.fromMillisecondsSinceEpoch(row.scheduledAt).toLocal();
    final isId = locale.languageCode == 'id';
    final firedAt = row.firedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.firedAt!);
    final now = DateTime.now();
    final canRetry = DeliveryRetryWindow.canRetry(
      scheduledAzan: when,
      now: now,
      firedAt: firedAt?.toLocal(),
    );
    final disabledReason = DeliveryRetryWindow.disabledReason(
      scheduledAzan: when,
      now: now,
      firedAt: firedAt?.toLocal(),
      isId: isId,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label:
            '${_prayerLabel(row.prayer)}, ${status.shortLabel(locale)}, $explanation',
        child: InkSurface(
          color: PrayerCastColors.canopyDeep,
          borderColor: PrayerCastColors.inkSoft,
          borderWidth: PrayerCastTheme.cardHairline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: status.icon(size: 26, color: status.foreground),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _prayerLabel(row.prayer),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusChip(status: status, locale: locale),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _historyDateLabel(when, locale),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          explanation,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: PrayerCastTheme.minTap,
                  child: FilledButton(
                    onPressed: canRetry && !retrying ? onRetry : null,
                    child: retrying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            canRetry
                                ? (isId ? 'Coba lagi' : 'Retry')
                                : (isId
                                    ? 'Coba lagi · $disabledReason'
                                    : 'Retry · $disabledReason'),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.locale});

  final OutcomeStatus status;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.shortLabel(locale),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: status.foreground,
              ),
        ),
      ),
    );
  }
}
