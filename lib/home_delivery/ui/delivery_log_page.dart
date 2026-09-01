import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../logging/delivery_database.dart';
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
///
/// Large type, clear status icons, and plain-language labels for both younger
/// and older users. Surfaces an OEM battery deep link after two
/// `FAILED_ALARM_MISSED` rows in seven days.
class DeliveryLogPage extends ConsumerWidget {
  const DeliveryLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      if (list.isEmpty) {
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
                                        ? 'Riwayat muncul setelah alarm adzan pertama berjalan.'
                                        : 'The log appears after the first adhan alarm runs.',
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
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          return FadeSlideIn(
                            delay: Duration(
                              milliseconds: 40 * index.clamp(0, 8),
                            ),
                            child: _AttemptRow(
                              row: list[index],
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

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.row,
    required this.locale,
  });

  final DeliveryLog row;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final outcome = Outcome.fromCode(row.outcome);
    final status = OutcomeStatus.of(outcome);
    final explanation = OutcomeExplanation.forOutcome(outcome, locale);
    final when = DateTime.fromMillisecondsSinceEpoch(row.scheduledAt).toLocal();
    final timeLabel =
        '${_weekday(when.weekday, locale)}, ${_two(when.day)}/${_two(when.month)}/${when.year}'
        '  ·  ${_two(when.hour)}:${_two(when.minute)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label:
            '${_prayerLabel(row.prayer)}, ${status.shortLabel(locale)}, $explanation',
        child: InkSurface(
          color: PrayerCastColors.canopyDeep,
          borderColor: PrayerCastColors.inkSoft,
          borderWidth: PrayerCastTheme.cardHairline,
          child: Row(
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
                      timeLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      explanation,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outcome.code,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            letterSpacing: 0.3,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _prayerLabel(String prayer) {
    if (prayer.isEmpty) return prayer;
    return prayer[0].toUpperCase() + prayer.substring(1);
  }

  static String _weekday(int weekday, Locale locale) {
    final id = locale.languageCode == 'id';
    const namesId = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const namesEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return (id ? namesId : namesEn)[(weekday - 1).clamp(0, 6)];
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
