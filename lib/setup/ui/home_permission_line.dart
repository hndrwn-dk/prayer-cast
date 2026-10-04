import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// One recovery action on home. Only mounted after onboarding finishes.
class HomePermissionLine extends StatelessWidget {
  const HomePermissionLine({
    super.key,
    required this.canSchedule,
    required this.notificationsGranted,
    required this.showBattery,
    required this.onRequestNotifications,
    required this.onRequestExactAlarm,
    required this.onOpenBatterySettings,
  });

  final bool canSchedule;
  final bool notificationsGranted;
  final bool showBattery;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExactAlarm;
  final VoidCallback onOpenBatterySettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String label;
    final VoidCallback onTap;
    if (!notificationsGranted) {
      label = l10n.onboardingRecoveryNotifications;
      onTap = onRequestNotifications;
    } else if (!canSchedule) {
      label = l10n.onboardingRecoveryAlarm;
      onTap = onRequestExactAlarm;
    } else if (showBattery) {
      label = l10n.onboardingRecoveryBattery;
      onTap = onOpenBatterySettings;
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        key: const ValueKey('home_permission_recovery'),
        color: PrayerCastTokens.dawnWash(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PrayerCastTokens.onDawnWash(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
