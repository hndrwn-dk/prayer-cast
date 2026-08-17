import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/premium_icons.dart';
import '../theme/prayer_cast_colors.dart';
import '../theme/prayer_cast_theme.dart';

/// Small-caps section label (DEVICE, SCHEDULE, NEXT ADHAN).
class EditorialEyebrow extends StatelessWidget {
  const EditorialEyebrow(
    this.label, {
    super.key,
    this.color = PrayerCastColors.mistDeep,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: PrayerCastTheme.editorialEyebrow(color),
    );
  }
}

/// Gold or mist hairline — presence marker, wordmark underline.
class EditorialHairline extends StatelessWidget {
  const EditorialHairline({
    super.key,
    this.color = PrayerCastColors.dawn,
    this.width = 36,
    this.height = 1,
    this.thickness = 1,
    this.vertical = false,
  });

  final Color color;
  final double width;
  final double height;
  final double thickness;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: SizedBox(
        width: vertical ? thickness : width,
        height: vertical ? height : thickness,
      ),
    );
  }
}

/// Back + optional eyebrow + Fraunces title — Speaker / Prayer times masthead.
class EditorialPageHeader extends StatelessWidget {
  const EditorialPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.onBack,
    this.backTooltip,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final VoidCallback? onBack;
  final String? backTooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: backTooltip ??
                MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: PremiumIcons.caretLeft(
              size: 26,
              color: PrayerCastColors.mist,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  EditorialEyebrow(
                    eyebrow!,
                    color: PrayerCastColors.dawn,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Dark canopy/ink slab with optional hairline border — replaces mint SoftCard.
class InkSurface extends StatelessWidget {
  const InkSurface({
    super.key,
    required this.child,
    this.color = PrayerCastColors.canopyDeep,
    this.borderColor,
    this.borderWidth = 1,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.borderRadius = 16,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  final Widget child;
  final Color color;
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
    final content = Padding(padding: padding, child: child);
    final border = borderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: border == null
            ? null
            : Border.all(color: border, width: borderWidth),
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

/// Rounded icon well used on Speaker row and list tiles.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.child,
    this.size = 36,
    this.color = PrayerCastColors.canopy,
    this.radius = 10,
  });

  final Widget child;
  final double size;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Quiet privacy line + version, separated from Prayer times by a mist hairline.
class ColophonFootnote extends StatelessWidget {
  const ColophonFootnote({
    super.key,
    required this.message,
    required this.versionLine,
    required this.onPrivacyTap,
    required this.privacyTooltip,
  });

  final String message;
  final String versionLine;
  final VoidCallback onPrivacyTap;
  final String privacyTooltip;

  static const Key dividerKey = ValueKey<String>('home_colophon_divider');
  static const Key privacyLinkKey = ValueKey<String>('privacy_policy_link');

  /// Mist hairline on ink — visible pembatas without a light strip.
  static Color get dividerColor =>
      PrayerCastColors.mist.withValues(alpha: 0.22);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PrayerCastColors.ink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            key: dividerKey,
            color: dividerColor,
            child: const SizedBox(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: privacyTooltip,
                  child: GestureDetector(
                    key: privacyLinkKey,
                    onTap: onPrivacyTap,
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontFamily: PrayerCastTheme.displayFont,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                        color: PrayerCastColors.mistDeep,
                        decoration: TextDecoration.underline,
                        decorationColor: PrayerCastColors.mistDeep,
                        decorationThickness: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  versionLine,
                  style: const TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    height: 1.3,
                    color: PrayerCastColors.mistDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint crescent wash for dark hero / forest pages.
class CrescentField extends StatelessWidget {
  const CrescentField({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        painter: _CrescentPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  const _CrescentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width - 72, 36);
    final mist = PrayerCastColors.mist.withValues(alpha: 0.16);
    final outer = Paint()
      ..color = mist
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final inner = Paint()
      ..color = mist
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawArc(
      Rect.fromCircle(center: origin, radius: 128),
      0.35,
      2.2,
      false,
      outer,
    );
    canvas.drawArc(
      Rect.fromCircle(center: origin.translate(-8, 8), radius: 108),
      0.4,
      2.1,
      false,
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dark forest page chrome: overlay, optional wash, header, body, bottom bar.
class ForestScaffold extends StatelessWidget {
  const ForestScaffold({
    super.key,
    required this.header,
    required this.body,
    this.bottom,
    this.backgroundColor = PrayerCastColors.ink,
    this.wash = true,
  });

  final Widget header;
  final Widget body;
  final Widget? bottom;
  final Color backgroundColor;
  final bool wash;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (wash) const CrescentField(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(bottom: false, child: header),
                Expanded(child: body),
                if (bottom != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: bottom!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
