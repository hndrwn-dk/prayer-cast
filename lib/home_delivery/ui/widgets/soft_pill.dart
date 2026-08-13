import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Compact mist pill for status chips and labels.
class SoftPill extends StatelessWidget {
  const SoftPill({
    super.key,
    required this.label,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? PrayerCastColors.canopyDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? PrayerCastColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
