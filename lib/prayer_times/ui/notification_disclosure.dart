import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Short prompt before the Android 13+ notification permission dialog.
///
/// Shown only when [POST_NOTIFICATIONS] is not already granted. Skipping
/// still schedules the dry-run; the shade may stay empty.
Future<bool> showNotificationDisclosureDialog(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: PrayerCastColors.ink.withValues(alpha: 0.72),
    builder: (ctx) => const NotificationDisclosureDialog(),
  );
  return proceed ?? false;
}

class NotificationDisclosureDialog extends StatelessWidget {
  const NotificationDisclosureDialog({super.key});

  static const Key dialogKey =
      ValueKey<String>('notification_disclosure');
  static const Key continueKey =
      ValueKey<String>('notification_disclosure_continue');
  static const Key skipKey =
      ValueKey<String>('notification_disclosure_skip');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: PrayerCastTheme.forest(),
      child: AlertDialog(
        key: dialogKey,
        backgroundColor: PrayerCastColors.canopyDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: PrayerCastColors.ink.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: PrayerCastColors.mist.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        title: Text(
          l10n.notificationDisclosureTitle,
          style: const TextStyle(
            color: PrayerCastColors.surfaceRaised,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        content: Text(
          l10n.notificationDisclosureBody,
          style: const TextStyle(
            color: PrayerCastColors.mist,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            key: skipKey,
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: PrayerCastColors.mist,
            ),
            child: Text(
              l10n.notificationDisclosureSkip,
              style: const TextStyle(color: PrayerCastColors.mist),
            ),
          ),
          FilledButton(
            key: continueKey,
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: PrayerCastColors.canopy,
              foregroundColor: PrayerCastColors.surfaceRaised,
            ),
            child: Text(
              l10n.notificationDisclosureContinue,
              style: const TextStyle(color: PrayerCastColors.surfaceRaised),
            ),
          ),
        ],
      ),
    );
  }
}
