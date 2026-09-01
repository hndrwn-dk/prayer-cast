import 'package:flutter/widgets.dart';

import '../logging/outcome.dart';
import 'icons/premium_icons.dart';
import 'theme/prayer_cast_colors.dart';

enum OutcomeKind { success, quiet, problem }

typedef PremiumIconBuilder = Widget Function({double size, Color? color});

/// Human-friendly status presentation for young and older users.
final class OutcomeStatus {
  const OutcomeStatus({
    required this.kind,
    required this.shortLabelBi,
    required this.shortLabelEn,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final OutcomeKind kind;
  final String shortLabelBi;
  final String shortLabelEn;
  final PremiumIconBuilder icon;
  final Color foreground;
  final Color background;

  String shortLabel(Locale locale) =>
      locale.languageCode == 'id' ? shortLabelBi : shortLabelEn;

  static OutcomeStatus of(Outcome outcome) {
    switch (outcome) {
      case Outcome.played:
        return const OutcomeStatus(
          kind: OutcomeKind.success,
          shortLabelBi: 'Berhasil',
          shortLabelEn: 'Played',
          icon: PremiumIcons.speaker,
          foreground: PrayerCastColors.canopyDeep,
          background: PrayerCastColors.mist,
        );
      case Outcome.suppressedAway:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Di luar rumah',
          shortLabelEn: 'Away',
          icon: PremiumIcons.house,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
      case Outcome.suppressedNotLeader:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Perangkat lain',
          shortLabelEn: 'Other device',
          icon: PremiumIcons.devices,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
      case Outcome.suppressedAlreadyPlaying:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Sudah diputar',
          shortLabelEn: 'Already playing',
          icon: PremiumIcons.prohibit,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
      case Outcome.suppressedUserDnd:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Mode tenang',
          shortLabelEn: 'Quiet hours',
          icon: PremiumIcons.moonStars,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
      case Outcome.failedNoTarget:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Speaker hilang',
          shortLabelEn: 'No speaker',
          icon: PremiumIcons.speakerSlash,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.failedNoRoute:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Jaringan gagal',
          shortLabelEn: 'No route',
          icon: PremiumIcons.wifiSlash,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.failedCastConnect:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Gagal sambung',
          shortLabelEn: 'Connect failed',
          icon: PremiumIcons.plug,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.failedLoadMedia:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Audio ditolak',
          shortLabelEn: 'Load failed',
          icon: PremiumIcons.musicMinus,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.failedAlarmMissed:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Alarm terlambat',
          shortLabelEn: 'Alarm late',
          icon: PremiumIcons.batteryWarning,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.clockSkew:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Jam melenceng',
          shortLabelEn: 'Clock skew',
          icon: PremiumIcons.clock,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
      case Outcome.failedReschedule:
        return const OutcomeStatus(
          kind: OutcomeKind.problem,
          shortLabelBi: 'Jadwal gagal',
          shortLabelEn: 'Reschedule failed',
          icon: PremiumIcons.clock,
          foreground: PrayerCastColors.danger,
          background: PrayerCastColors.dangerSoft,
        );
      case Outcome.rescheduleRetryArmed:
        return const OutcomeStatus(
          kind: OutcomeKind.quiet,
          shortLabelBi: 'Coba ulang',
          shortLabelEn: 'Retry armed',
          icon: PremiumIcons.refresh,
          foreground: PrayerCastColors.quiet,
          background: Color(0xFFE4EBE6),
        );
    }
  }
}
