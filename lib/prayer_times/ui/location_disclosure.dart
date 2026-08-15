import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
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
    barrierColor: PrayerCastColors.ink.withValues(alpha: 0.72),
    builder: (ctx) => const LocationDisclosureDialog(),
  );
  return proceed ?? false;
}

/// Editorial one-screen disclosure (forest / ink).
class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  static const Key dialogKey = ValueKey<String>('location_disclosure');
  static const Key continueKey = ValueKey<String>('location_disclosure_continue');
  static const Key typeCityKey = ValueKey<String>('location_disclosure_type_city');
  static const Key privacyKey = ValueKey<String>('location_disclosure_privacy');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      key: dialogKey,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxHeight),
        child: InkSurface(
          borderColor: PrayerCastColors.inkSoft,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.locationDisclosureTitle,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.locationDisclosureBody,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: privacyKey,
                          onPressed: () => openPrivacyPolicyUrl(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(l10n.privacyPolicy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: PrayerCastTheme.minTap,
                child: FilledButton(
                  key: continueKey,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.locationDisclosureContinue),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: PrayerCastTheme.minTap,
                child: TextButton(
                  key: typeCityKey,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.locationDisclosureTypeCity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
