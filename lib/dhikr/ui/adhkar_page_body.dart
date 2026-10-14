import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/data/adhkar_content_data.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Shared layout for the morning and evening adhkar pages: settings,
/// "Test now" Cast button, and a scrollable Arabic + translation list.
class AdhkarPageBody extends ConsumerWidget {
  const AdhkarPageBody({super.key, required this.type, this.listKey});

  final AdhkarType type;
  final Key? listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isMorning = type == AdhkarType.morning;
    final enabled = ref.watch(adhkarEnabledProvider(type));
    final delay = ref.watch(adhkarDelayProvider(type));
    final coordinator = ref.watch(adhkarDeliveryCoordinatorProvider);
    final content = isMorning
        ? AdhkarContentData.morning(l10n)
        : AdhkarContentData.evening(l10n);

    return Scaffold(
      backgroundColor: PrayerCastTokens.surface(context),
      body: Column(
        children: [
          EditorialPageHeader(
            eyebrow: isMorning ? l10n.afterFajr : l10n.afterAsr,
            title: isMorning ? l10n.morningAdhkar : l10n.eveningAdhkar,
            backTooltip: l10n.back,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              key: listKey,
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.enableAdhkar,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PrayerCastTokens.onSurface(context),
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (v) => toggleAdhkarEnabled(ref, type, v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.delayMinutes,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 14,
                    color: PrayerCastTokens.glyphMuted(context),
                  ),
                ),
                Slider(
                  value: delay.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 24,
                  label: '$delay min',
                  onChanged: (v) => updateAdhkarDelay(ref, type, v.round()),
                ),
                const SizedBox(height: 8),
                Text(
                  isMorning
                      ? l10n.timingGuidanceMorning
                      : l10n.timingGuidanceEvening,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: PrayerCastTokens.glyphMuted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: coordinator == null
                        ? null
                        : () => _testNow(context, coordinator),
                    icon: const Icon(Icons.speaker_outlined),
                    label: Text(l10n.testAdhkarNow),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                Text(
                  l10n.adhkarContentSection,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PrayerCastTokens.onSurface(context),
                  ),
                ),
                const SizedBox(height: 16),
                for (final adhkar in content)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _AdhkarContentCard(
                      arabic: adhkar.arabic,
                      translation: adhkar.translation,
                      count: adhkar.count,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testNow(
    BuildContext context,
    AdhkarDeliveryCoordinator coordinator,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await coordinator.testAdhkar(type);
    if (result == AdhkarDeliveryResult.success) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.castFailed(result.name))),
    );
  }
}

class _AdhkarContentCard extends StatelessWidget {
  const _AdhkarContentCard({
    required this.arabic,
    required this.translation,
    required this.count,
  });

  final String arabic;
  final String translation;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          arabic,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: PrayerCastTheme.displayFont,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: PrayerCastTokens.onSurface(context),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          translation,
          style: TextStyle(
            fontFamily: PrayerCastTheme.bodyFont,
            fontSize: 14,
            color: PrayerCastTokens.glyphMuted(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: PrayerCastColors.dawn.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${count}x',
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PrayerCastColors.canopyDeep,
            ),
          ),
        ),
      ],
    );
  }
}
