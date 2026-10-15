import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/aladhan_client.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';

/// Wall clock for the adhkar NOW window. Override in tests.
/// The grid calls this; it does not read [DateTime.now] itself.
final homeMenuClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Which adhkar tile is inside its prayer window.
enum HomeAdhkarWindow { none, morning, evening }

/// Morning is from Fajr until Dhuhr. Evening is from Asr until Isha.
HomeAdhkarWindow homeAdhkarWindow({
  required DateTime now,
  AladhanDaySchedule? schedule,
}) {
  if (schedule == null) return HomeAdhkarWindow.none;
  DateTime? slot(String name) {
    for (final prayer in schedule.slots) {
      if (prayer.name == name) return prayer.scheduledAt;
    }
    return null;
  }

  final fajr = slot('fajr');
  final dhuhr = slot('dhuhr');
  final asr = slot('asr');
  final isha = slot('isha');
  if (fajr != null &&
      dhuhr != null &&
      !now.isBefore(fajr) &&
      now.isBefore(dhuhr)) {
    return HomeAdhkarWindow.morning;
  }
  if (asr != null && isha != null && !now.isBefore(asr) && now.isBefore(isha)) {
    return HomeAdhkarWindow.evening;
  }
  return HomeAdhkarWindow.none;
}

/// Home menu: three columns, two rows, large enough for older readers.
class HomeMenuGrid extends ConsumerWidget {
  const HomeMenuGrid({
    super.key,
    required this.onPrayerTimes,
    required this.onPrayerTracker,
    required this.onQibla,
  });

  final VoidCallback onPrayerTimes;
  final VoidCallback onPrayerTracker;
  final VoidCallback onQibla;

  static const ValueKey<String> gridKey = ValueKey<String>('home_menu_grid');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(homeMenuClockProvider)();
    final schedule = ref.watch(todayScheduleProvider).asData?.value;
    final window = homeAdhkarWindow(now: now, schedule: schedule);
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Padding(
      key: gridKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          _MenuRow(
            tiles: [
              _MenuTile(
                tileKey: const ValueKey<String>('home_prayer_times_slab'),
                label: l10n.prayerTimes,
                icon: PremiumIcons.clock(
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                onTap: onPrayerTimes,
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_prayer_tracker_slab'),
                label: l10n.prayerTracker,
                icon: PremiumIcons.bars(
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                onTap: onPrayerTracker,
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_qibla_slab'),
                label: l10n.qibla,
                icon: const Icon(
                  Icons.explore_outlined,
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                onTap: onQibla,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MenuRow(
            tiles: [
              _MenuTile(
                tileKey: const ValueKey<String>('home_morning_adhkar'),
                label: l10n.morningAdhkar,
                icon: PremiumIcons.sunrise(
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                showNow: window == HomeAdhkarWindow.morning,
                onTap: () => open(const MorningAdhkarPage()),
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_evening_adhkar'),
                label: l10n.eveningAdhkar,
                icon: PremiumIcons.sunset(
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                showNow: window == HomeAdhkarWindow.evening,
                onTap: () => open(const EveningAdhkarPage()),
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_dhikr_counter'),
                label: l10n.generalDhikr,
                icon: const Icon(
                  Icons.exposure_plus_1_outlined,
                  size: 28,
                  color: PrayerCastColors.canopy,
                ),
                onTap: () => open(const DhikrCounterPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.tileKey,
    required this.label,
    required this.icon,
    required this.onTap,
    this.showNow = false,
  });

  final Key tileKey;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool showNow;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final labelSlot = scaler.scale(16 * 1.2) * 2;

    return Semantics(
      key: tileKey,
      button: true,
      label: label,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Material(
            color: PrayerCastColors.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: showNow ? PrayerCastColors.dawn : PrayerCastColors.mist,
                width: showNow ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 124),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: PrayerCastTokens.leafWash(context, 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Center(child: icon),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: labelSlot),
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: PrayerCastTheme.displayFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: PrayerCastTokens.onSurface(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showNow)
            const Positioned(
              top: -10,
              child: IgnorePointer(child: _NowBadge()),
            ),
        ],
      ),
    );
  }
}

class _NowBadge extends StatelessWidget {
  const _NowBadge();

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(PrayerCastColors.dawn);
    final fill = hsl.withLightness(0.28).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.l10n.dhikrNowBadge,
          style: const TextStyle(
            fontFamily: PrayerCastTheme.bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: PrayerCastColors.surfaceRaised,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
