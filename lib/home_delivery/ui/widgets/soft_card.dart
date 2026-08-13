import 'package:flutter/material.dart';

import '../theme/prayer_cast_colors.dart';

/// Soft raised surface used on home and prayer settings.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.borderRadius = 22,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final content = Padding(
      padding: padding,
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PrayerCastColors.surfaceRaised.withValues(alpha: 0.92),
        borderRadius: radius,
        border: Border.all(
          color: borderColor ??
              PrayerCastColors.mistDeep.withValues(alpha: 0.85),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: PrayerCastColors.canopyDeep.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(
                onTap: enabled ? onTap : null,
                onLongPress: enabled ? onLongPress : null,
                borderRadius: radius,
                child: content,
              ),
      ),
    );
  }
}
