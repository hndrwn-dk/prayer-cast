import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/support/open_support_url.dart';

/// Play prominent disclosure shown **before** the system location prompt.
///
/// Only used when permission is not already granted. GPS is optional and
/// never requested on launch or in the background.
Future<bool> showLocationDisclosureDialog(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: PrayerCastTokens.scrim(context),
    builder: (ctx) => const LocationDisclosureDialog(),
  );
  return proceed ?? false;
}

/// Editorial one-screen disclosure (forest / ink).
class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  static const Key dialogKey = ValueKey<String>('location_disclosure');
  static const Key continueKey = ValueKey<String>(
    'location_disclosure_continue',
  );
  static const Key typeCityKey = ValueKey<String>(
    'location_disclosure_type_city',
  );
  static const Key privacyKey = ValueKey<String>('location_disclosure_privacy');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleColor = PrayerCastTokens.panelTitle(context);
    final bodyColor = PrayerCastTokens.panelBody(context);
    final actionColor = PrayerCastTokens.isForest(context)
        ? PrayerCastColors.mist
        : PrayerCastColors.canopy;
    return AlertDialog(
      key: dialogKey,
      backgroundColor: PrayerCastTokens.panel(context),
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: PrayerCastColors.ink.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PrayerCastTokens.panelRule(context), width: 1),
      ),
      title: Text(
        l10n.locationDisclosureTitle,
        style: TextStyle(
          color: titleColor,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.locationDisclosureBody,
            style: TextStyle(
              color: bodyColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: privacyKey,
              onPressed: () => openPrivacyPolicyUrl(context),
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.privacyPolicy,
                style: TextStyle(color: actionColor),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: typeCityKey,
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: actionColor),
          child: Text(
            l10n.locationDisclosureTypeCity,
            style: TextStyle(color: actionColor),
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
            l10n.locationDisclosureContinue,
            style: const TextStyle(color: PrayerCastColors.surfaceRaised),
          ),
        ),
      ],
    );
  }
}
