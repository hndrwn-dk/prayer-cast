import 'package:flutter/material.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';

import 'theme/prayer_cast_colors.dart';
import 'theme/prayer_cast_theme.dart';
import 'widgets/editorial_chrome.dart';

/// Full spiritual-benefits card. Optional — never blocks adhan delivery.
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
    final title = prayerDisplayName(
      l10n,
      copy?.prayerKey ?? prayer,
    );

    return Theme(
      data: PrayerCastTheme.forest(),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      _BenefitsSection(
                        eyebrow: l10n.spiritualBenefitsSection,
                        children: [
                          for (final line in copy.benefits)
                            _BulletLine(line, style: text.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _BenefitsSection(
                        eyebrow: l10n.sunnahPracticesSection,
                        children: [
                          for (final line in copy.sunnah)
                            _BulletLine(line, style: text.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _BenefitsSection(
                        eyebrow: copy.asideKind == SpiritualAsideKind.saying
                            ? l10n.sayingSection
                            : l10n.noteSection,
                        children: [
                          Text(
                            copy.aside,
                            style: text.bodyLarge?.copyWith(
                              fontFamily: PrayerCastTheme.displayFont,
                              fontStyle: FontStyle.italic,
                              color: PrayerCastColors.mist,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({
    required this.eyebrow,
    required this.children,
  });

  final String eyebrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InkSurface(
      borderColor: PrayerCastColors.inkSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialEyebrow(
            eyebrow,
            color: PrayerCastColors.dawn,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.line, {this.style});

  final String line;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('·  ', style: style),
        Expanded(child: Text(line, style: style)),
      ],
    );
  }
}
