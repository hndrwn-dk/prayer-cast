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

/// Horizontal inset of the speaker card and the home-detected rule.
const double homeContentInset = 16;

const double _menuHorizontalPadding = 12;
const double _menuColumnGap = 4;
const double _menuRowGap = 20;
const double _menuCircleSize = 72;

/// Light NOW pill. A deeper dawn, used only on this badge.
const Color homeMenuNowFill = Color(0xFFA86A17);

/// Forest NOW pill. A lighter dawn, used only on this badge.
const Color homeMenuNowFillForest = Color(0xFFE3A54B);

List<BoxShadow> homeMenuCardShadow(BuildContext context) {
  if (PrayerCastTokens.isForest(context)) return const <BoxShadow>[];
  final ink = PrayerCastColors.ink.withValues(alpha: 0.06);
  return <BoxShadow>[
    BoxShadow(color: ink, blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: ink, blurRadius: 16, offset: const Offset(0, 6)),
  ];
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
    final forest = PrayerCastTokens.isForest(context);
    final iconColor = forest ? PrayerCastColors.mist : PrayerCastColors.canopy;
    final fillOpacity = forest ? 0.35 : 0.18;
    final now = ref.watch(homeMenuClockProvider)();
    final schedule = ref.watch(todayScheduleProvider).asData?.value;
    final window = homeAdhkarWindow(now: now, schedule: schedule);
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Padding(
      key: gridKey,
      padding: const EdgeInsets.fromLTRB(
        _menuHorizontalPadding,
        8,
        _menuHorizontalPadding,
        16,
      ),
      child: Column(
        children: [
          _MenuRow(
            tiles: [
              _MenuTile(
                tileKey: const ValueKey<String>('home_prayer_times_slab'),
                label: l10n.prayerTimes,
                icon: PremiumIcons.prayerTimes(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
                ),
                onTap: onPrayerTimes,
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_prayer_tracker_slab'),
                label: l10n.prayerTracker,
                icon: PremiumIcons.prayerTracker(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
                ),
                onTap: onPrayerTracker,
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_qibla_slab'),
                label: l10n.qibla,
                icon: PremiumIcons.qibla(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
                ),
                onTap: onQibla,
              ),
            ],
          ),
          const SizedBox(height: _menuRowGap),
          _MenuRow(
            tiles: [
              _MenuTile(
                tileKey: const ValueKey<String>('home_morning_adhkar'),
                label: l10n.morningAdhkar,
                icon: PremiumIcons.morningAdhkar(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
                ),
                showNow: window == HomeAdhkarWindow.morning,
                onTap: () => open(const MorningAdhkarPage()),
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_evening_adhkar'),
                label: l10n.eveningAdhkar,
                icon: PremiumIcons.eveningAdhkar(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
                ),
                showNow: window == HomeAdhkarWindow.evening,
                onTap: () => open(const EveningAdhkarPage()),
              ),
              _MenuTile(
                tileKey: const ValueKey<String>('home_dhikr_counter'),
                label: l10n.generalDhikr,
                icon: PremiumIcons.tasbih(
                  size: 34,
                  color: iconColor,
                  fillOpacity: fillOpacity,
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
          if (i > 0) const SizedBox(width: _menuColumnGap),
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
    final forest = PrayerCastTokens.isForest(context);
    final badge = context.l10n.dhikrNowBadge;
    final circleColor = forest ? PrayerCastColors.canopy : Colors.white;
    final borderColor = showNow
        ? PrayerCastColors.dawn
        : PrayerCastColors.dawn.withValues(alpha: 0.35);

    return Semantics(
      key: tileKey,
      button: true,
      label: showNow ? '$label, $badge' : label,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MenuCircle(
                      color: circleColor,
                      borderColor: borderColor,
                      borderWidth: showNow ? 2 : 1,
                      shadow: forest
                          ? const <BoxShadow>[]
                          : homeMenuCardShadow(context),
                      showNow: showNow,
                      ringColor: showNow
                          ? PrayerCastColors.dawn.withValues(
                              alpha: forest ? 0.18 : 0.16,
                            )
                          : null,
                      icon: icon,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.displayFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: PrayerCastTokens.onSurface(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCircle extends StatelessWidget {
  const _MenuCircle({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.shadow,
    required this.showNow,
    required this.ringColor,
    required this.icon,
  });

  final Color color;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadow;
  final bool showNow;
  final Color? ringColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _menuCircleSize,
      height: _menuCircleSize,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (ringColor != null)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor!, width: 4),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadow,
            ),
            child: Center(child: icon),
          ),
          if (showNow)
            const Positioned(
              top: 0,
              left: _menuCircleSize / 2 + 18,
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
    final forest = PrayerCastTokens.isForest(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: forest ? homeMenuNowFillForest : homeMenuNowFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PrayerCastTokens.surface(context), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          context.l10n.dhikrNowBadge,
          style: TextStyle(
            fontFamily: PrayerCastTheme.bodyFont,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            height: 1.2,
            color: forest ? PrayerCastColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}
