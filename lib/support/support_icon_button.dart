import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/support/open_support_url.dart';

/// Compact Ko-fi support control for the home brand row.
class SupportIconButton extends StatelessWidget {
  const SupportIconButton({
    super.key,
    this.iconButtonKey,
    this.color = PrayerCastColors.canopy,
  });

  final Key? iconButtonKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      key: iconButtonKey ?? const ValueKey('support_on_kofi'),
      tooltip: l10n.supportOnKofi,
      onPressed: () => openSupportUrl(context),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(8),
      ),
      icon: Icon(
        Icons.volunteer_activism,
        size: 22,
        color: color,
      ),
    );
  }
}
