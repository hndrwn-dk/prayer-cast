import 'package:flutter/material.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

/// Shared first-run chrome: progress + mark + optional bottom CTAs.
///
/// Follows the ambient (usually light) theme — same register as Qibla.
/// Does not wrap speaker scan or prayer settings; those stay full pages.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.stage,
    required this.eyebrow,
    required this.title,
    this.mark,
    this.center,
    this.body,
    this.bodySlot,
    this.markCaption,
    this.markKey,
    this.onMarkTap,
    this.primaryLabel,
    this.primaryKey,
    this.onPrimary,
    this.secondaryLabel,
    this.secondaryKey,
    this.onSecondary,
    this.onBack,
    this.primaryEnabled = true,
    this.busy = false,
  }) : assert(mark != null || center != null || bodySlot != null);

  final OnboardingStage stage;
  final String eyebrow;
  final String title;

  /// Single center mark. Ignored when [center] or [bodySlot] is set.
  final Widget? mark;

  /// Custom center content (e.g. two mark CTAs). Replaces [mark].
  final Widget? center;
  final String? body;

  /// Full body replacement (e.g. speaker list). Skips the centered mark column.
  final Widget? bodySlot;

  /// Quiet label under the center mark (e.g. location CTA).
  final String? markCaption;
  final Key? markKey;
  final VoidCallback? onMarkTap;

  final String? primaryLabel;
  final Key? primaryKey;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final Key? secondaryKey;
  final VoidCallback? onSecondary;
  final VoidCallback? onBack;

  final bool primaryEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final backColor = PrayerCastTokens.onSurface(context);
    final titleStyle = TextStyle(
      fontFamily: PrayerCastTheme.displayFont,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.4,
      color: PrayerCastTokens.onSurface(context),
      fontVariations: const [FontVariation('wght', 600)],
    );
    final markChild = mark;
    final markWell = markChild == null
        ? null
        : OnboardingMarkWell(
            size: 112,
            iconSize: 44,
            busy: busy,
            child: markChild,
          );

    final captionStyle = text.titleMedium?.copyWith(
      color: PrayerCastColors.dawn,
      fontWeight: FontWeight.w700,
    );
    final markBlock = markWell == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              markWell,
              if (markCaption != null) ...[
                const SizedBox(height: 16),
                Text(
                  markCaption!,
                  textAlign: TextAlign.center,
                  style: captionStyle,
                ),
              ],
            ],
          );

    final bodyContent = bodySlot ??
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (center != null)
                          center!
                        else if (markBlock != null) ...[
                          if (onMarkTap != null)
                            GestureDetector(
                              key: markKey,
                              behavior: HitTestBehavior.translucent,
                              onTap: busy ? null : onMarkTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: markBlock,
                              ),
                            )
                          else
                            KeyedSubtree(key: markKey, child: markBlock),
                        ],
                        if (body != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            body!,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: PrayerCastTokens.glyph(context),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );

    final showSkip = secondaryLabel != null && onSecondary != null;
    final showPrimary = primaryLabel != null && onPrimary != null;
    final showFooter = showSkip || showPrimary;
    const dawnAction = TextStyle(
      color: PrayerCastColors.dawn,
      fontWeight: FontWeight.w700,
      fontSize: 17,
      fontFamily: PrayerCastTheme.bodyFont,
    );

    return ForestScaffold(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    key: const ValueKey('onboarding_back'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: onBack,
                    icon: PremiumIcons.caretLeft(size: 26, color: backColor),
                  )
                else
                  const SizedBox(width: 48, height: 48),
                const Spacer(),
                Text(
                  key: const ValueKey('onboarding_progress'),
                  '${stage.number} / ${OnboardingStage.total}',
                  style: text.labelLarge?.copyWith(
                    color: PrayerCastTokens.glyphMuted(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditorialEyebrow(eyebrow, color: PrayerCastColors.dawn),
                  const SizedBox(height: 8),
                  Text(title, style: titleStyle),
                ],
              ),
            ),
          ],
        ),
      ),
      body: bodyContent,
      bottom: showFooter
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSkip) ...[
                    SizedBox(
                      width: double.infinity,
                      height: PrayerCastTheme.minTap,
                      child: TextButton(
                        key: secondaryKey,
                        onPressed: busy ? null : onSecondary,
                        style: TextButton.styleFrom(
                          foregroundColor: PrayerCastColors.dawn,
                        ),
                        child: Text(secondaryLabel!, style: dawnAction),
                      ),
                    ),
                    if (showPrimary) const SizedBox(height: 4),
                  ],
                  if (showPrimary)
                    SizedBox(
                      width: double.infinity,
                      height: PrayerCastTheme.minTap,
                      child: FilledButton(
                        key: primaryKey,
                        onPressed: busy || !primaryEnabled ? null : onPrimary,
                        child: Text(primaryLabel!),
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

/// Open qibla-style mark — ink/dawn rings, no fill.
class OnboardingMarkWell extends StatelessWidget {
  const OnboardingMarkWell({
    super.key,
    required this.child,
    this.size = 104,
    this.busy = false,
    this.iconSize = 40,
  });

  final Widget child;
  final double size;
  final bool busy;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final forest = PrayerCastTokens.isForest(context);
    const glyph = PrayerCastColors.dawn;
    final outer = forest
        ? PrayerCastColors.mist.withValues(alpha: 0.38)
        : PrayerCastColors.ink.withValues(alpha: 0.28);
    final inner = PrayerCastColors.dawn.withValues(alpha: 0.9);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _MarkRingPainter(outer: outer, inner: inner),
          ),
          busy
              ? SizedBox(
                  width: iconSize * 0.7,
                  height: iconSize * 0.7,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: glyph,
                  ),
                )
              : IconTheme(
                  data: IconThemeData(color: glyph, size: iconSize),
                  child: child,
                ),
        ],
      ),
    );
  }
}

class _MarkRingPainter extends CustomPainter {
  const _MarkRingPainter({required this.outer, required this.inner});

  final Color outer;
  final Color inner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..color = outer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(
      c,
      r - 8,
      Paint()
        ..color = inner
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkRingPainter oldDelegate) =>
      oldDelegate.outer != outer || oldDelegate.inner != inner;
}

/// Round mark + caption used as a center CTA (audio choice, location, …).
class OnboardingMarkChoice extends StatelessWidget {
  const OnboardingMarkChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: OnboardingMarkWell(child: icon),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 128,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(
              color: PrayerCastTokens.onSurface(context),
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Linear progress for the premium shell (speaker and phone share stage 2).
enum OnboardingStage {
  audio(1),
  delivery(2),
  prayer(3),
  notifications(4),
  alarm(5),
  battery(6);

  const OnboardingStage(this.number);
  final int number;
  static const total = 6;

  static OnboardingStage fromStep(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.audio => OnboardingStage.audio,
      OnboardingStep.speaker || OnboardingStep.phone => OnboardingStage.delivery,
      OnboardingStep.prayer => OnboardingStage.prayer,
      OnboardingStep.notifications => OnboardingStage.notifications,
      OnboardingStep.alarm => OnboardingStage.alarm,
      OnboardingStep.battery || OnboardingStep.completed =>
        OnboardingStage.battery,
    };
  }
}
