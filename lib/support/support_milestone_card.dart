import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Small home card shown when a speaker-adhan milestone is newly reached.
class SupportMilestoneCard extends StatelessWidget {
  const SupportMilestoneCard({
    super.key,
    required this.count,
    required this.onSupport,
    required this.onDismiss,
  });

  static const cardKey = ValueKey<String>('support_milestone_card');

  final int count;
  final VoidCallback onSupport;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      key: cardKey,
      color: PrayerCastTokens.panel(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PrayerCastTokens.panelRule(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportMilestoneBody(count),
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: PrayerCastTokens.panelTitle(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.supportMilestoneInvite,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 13,
                height: 1.4,
                color: PrayerCastTokens.panelBody(context),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: onSupport,
                  child: Text(l10n.supportMilestoneAction),
                ),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.supportClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
