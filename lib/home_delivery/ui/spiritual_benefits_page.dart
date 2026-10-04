import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';

import 'theme/prayer_cast_colors.dart';
import 'theme/prayer_cast_theme.dart';
import 'theme/prayer_cast_tokens.dart';
import 'widgets/editorial_chrome.dart';

/// Full spiritual-benefits card. Optional — never blocks adhan delivery.
///
/// Editorial open layout (no boxed panels) so light and forest stay premium.
class SpiritualBenefitsPage extends StatelessWidget {
  const SpiritualBenefitsPage({super.key, required this.prayer});

  final String prayer;

  static const String routeName = 'spiritual_benefits';
  static const ValueKey<String> keyName = ValueKey<String>(
    'spiritual_benefits_page',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final copy = SpiritualBenefits.of(l10n, prayer);
    final title = prayerDisplayName(l10n, copy?.prayerKey ?? prayer);

    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: l10n.spiritualBenefitsSection,
        title: title,
        backTooltip: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: copy == null
          ? const SizedBox.shrink()
          : ListView(
              key: keyName,
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
              children: [
                _EditorialSection(
                  eyebrow: l10n.spiritualBenefitsSection,
                  child: _BulletList(copy.benefits),
                ),
                const _SectionRule(),
                _EditorialSection(
                  eyebrow: l10n.sunnahPracticesSection,
                  child: _BulletList(copy.sunnah),
                ),
                const _SectionRule(),
                _EditorialSection(
                  eyebrow: copy.asideKind == SpiritualAsideKind.saying
                      ? l10n.sayingSection
                      : l10n.noteSection,
                  child: Text(
                    copy.aside,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: PrayerCastTheme.displayFont,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                      color: PrayerCastTokens.glyphMuted(context),
                      fontVariations: const [FontVariation('wght', 500)],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: PrayerCastTokens.rule(context), width: 1),
          ),
        ),
        child: const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

class _EditorialSection extends StatelessWidget {
  const _EditorialSection({required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialEyebrow(eyebrow, color: PrayerCastColors.dawn),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _BulletLine(lines[i]),
        ],
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge?.copyWith(
      color: PrayerCastTokens.glyph(context),
      height: 1.45,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: PrayerCastColors.dawn,
              shape: BoxShape.circle,
            ),
            child: const SizedBox(width: 5, height: 5),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(line, style: body)),
      ],
    );
  }
}
