import 'package:flutter/material.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_page.dart';
import 'package:prayer_cast/dhikr/ui/evening_adhkar_page.dart';
import 'package:prayer_cast/dhikr/ui/morning_adhkar_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Second row of home destinations, built to the exact metrics of the
/// Schedule / Worship / Direction strip above it (same padding, 24 px pipe
/// slots, eyebrow + one-line Fraunces title), so the two rows read as one
/// 3×2 grid with columns that line up.
///
/// Speaker on/off lives in each adhkar page's settings, not here.
class HomeDhikrSection extends StatelessWidget {
  const HomeDhikrSection({super.key});

  static const ValueKey<String> rowKey = ValueKey<String>('home_dhikr_strip');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void open(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return Padding(
      key: rowKey,
      // Top 0: sits directly under the destinations strip (bottom 20).
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _DhikrCell(
                cellKey: const ValueKey<String>('home_morning_adhkar'),
                eyebrow: l10n.afterFajr,
                title: l10n.morningAdhkar,
                onTap: () => open(const MorningAdhkarPage()),
              ),
            ),
            const _Pipe(),
            Expanded(
              child: _DhikrCell(
                cellKey: const ValueKey<String>('home_evening_adhkar'),
                eyebrow: l10n.afterAsr,
                title: l10n.eveningAdhkar,
                onTap: () => open(const EveningAdhkarPage()),
              ),
            ),
            const _Pipe(),
            Expanded(
              child: _DhikrCell(
                cellKey: const ValueKey<String>('home_dhikr_counter'),
                eyebrow: l10n.dhikrAnytimeEyebrow,
                title: l10n.generalDhikr,
                onTap: () => open(const DhikrCounterPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same slot as main.dart's _PipeDivider.
class _Pipe extends StatelessWidget {
  const _Pipe();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Center(
        child: ColoredBox(
          color: PrayerCastTokens.isForest(context)
              ? PrayerCastColors.mistDeep.withValues(alpha: 0.55)
              : PrayerCastColors.dawn,
          child: const SizedBox(width: 1, height: 20),
        ),
      ),
    );
  }
}

/// Same layout as main.dart's _DestinationCell.
class _DhikrCell extends StatelessWidget {
  const _DhikrCell({
    required this.cellKey,
    required this.eyebrow,
    required this.title,
    required this.onTap,
  });

  final Key cellKey;
  final String eyebrow;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        key: cellKey,
        color: PrayerCastTokens.surface(context),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PrayerCastTheme.minTap,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EditorialEyebrow(eyebrow, color: PrayerCastColors.dawn),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.displayFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          letterSpacing: -0.2,
                          color: PrayerCastTokens.onSurface(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
