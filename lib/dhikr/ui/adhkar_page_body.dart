import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/data/adhkar_content_data.dart';
import 'package:prayer_cast/dhikr/models/adhkar_content.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_delivery_coordinator.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_providers.dart';
import 'package:prayer_cast/dhikr/ui/widgets/counter_progress.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// Morning / evening adhkar as a reader: one dhikr per page, swiped or
/// advanced with the button at the bottom. Items read more than once get
/// a tap counter that moves on by itself at the target.
///
/// Speaker and schedule settings live in a sheet behind the header's tune
/// icon, so opening the page goes straight to the first dhikr.
class AdhkarPageBody extends ConsumerStatefulWidget {
  const AdhkarPageBody({super.key, required this.type, this.listKey});

  final AdhkarType type;
  final Key? listKey;

  static const ValueKey<String> settingsButtonKey =
      ValueKey<String>('adhkar_settings_button');
  static const ValueKey<String> advanceButtonKey =
      ValueKey<String>('adhkar_advance_button');

  @override
  ConsumerState<AdhkarPageBody> createState() => _AdhkarPageBodyState();
}

class _AdhkarPageBodyState extends ConsumerState<AdhkarPageBody> {
  static const Duration _autoAdvanceDelay = Duration(milliseconds: 550);

  final PageController _pages = PageController();
  final Map<String, int> _reads = {};
  int _page = 0;
  bool _advancing = false;

  bool get _isMorning => widget.type == AdhkarType.morning;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _tapCount(AdhkarContent item) {
    if (_advancing) return;
    final next = (_reads[item.id] ?? 0) + 1;
    if (next > item.count) return;
    setState(() => _reads[item.id] = next);
    if (next < item.count) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.heavyImpact();
    _advancing = true;
    Future<void>.delayed(_autoAdvanceDelay, () {
      if (!mounted) return;
      _advancing = false;
      _goTo(_page + 1);
    });
  }

  void _undoCount(AdhkarContent item) {
    final current = _reads[item.id] ?? 0;
    if (current == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _reads[item.id] = current - 1);
  }

  void _restart() {
    setState(_reads.clear);
    _pages.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = _isMorning
        ? AdhkarContentData.morning(l10n)
        : AdhkarContentData.evening(l10n);
    final total = content.length;
    final onCompletion = _page >= total;

    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: _isMorning ? l10n.afterFajr : l10n.afterAsr,
        title: _isMorning ? l10n.morningAdhkar : l10n.eveningAdhkar,
        backTooltip: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
        trailing: IconButton(
          key: AdhkarPageBody.settingsButtonKey,
          tooltip: l10n.adhkarSettings,
          icon: Icon(
            Icons.tune_rounded,
            color: PrayerCastTokens.glyph(context),
          ),
          onPressed: () => _openSettings(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  onCompletion
                      ? l10n.adhkarCompleteTitle
                      : l10n.adhkarProgress(_page + 1, total),
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 13,
                    color: PrayerCastTokens.glyphMuted(context),
                  ),
                ),
                const SizedBox(height: 6),
                CounterProgress(
                  progress: onCompletion ? 1.0 : (_page + 1) / total,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              key: widget.listKey,
              controller: _pages,
              itemCount: total + 1,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) => i < total
                  ? _AdhkarReadingCard(item: content[i])
                  : _CompletionCard(onRestart: _restart),
            ),
          ),
        ],
      ),
      bottom: onCompletion
          ? null
          : _ReadingControls(
              item: content[_page],
              reads: _reads[content[_page].id] ?? 0,
              isLast: _page == total - 1,
              onTapCount: () => _tapCount(content[_page]),
              onUndo: () => _undoCount(content[_page]),
              onNext: () {
                final item = content[_page];
                setState(() => _reads[item.id] = item.count);
                _goTo(_page + 1);
              },
            ),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PrayerCastTokens.surface(context),
      builder: (_) => _AdhkarSettingsSheet(type: widget.type),
    );
  }
}

/// One dhikr: count and source, Arabic, then optional transliteration and
/// translation. Scrolls on its own for the long items (Ayat al-Kursi).
class _AdhkarReadingCard extends ConsumerWidget {
  const _AdhkarReadingCard({required this.item});

  final AdhkarContent item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final showTranslit = ref.watch(adhkarShowTransliterationProvider);
    final showTranslation = ref.watch(adhkarShowTranslationProvider);
    final scale = ref.watch(adhkarArabicScaleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: PrayerCastColors.dawn.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.adhkarRepeatTimes(item.count),
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PrayerCastTokens.isForest(context)
                        ? PrayerCastColors.dawnSoft
                        : PrayerCastColors.canopyDeep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 12,
                    color: PrayerCastTokens.glyphMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            item.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: PrayerCastTheme.arabicFont,
              fontSize: 26 * scale,
              height: 2.0,
              locale: const Locale('ar'),
              color: PrayerCastTokens.onSurface(context),
            ),
          ),
          if (showTranslit) ...[
            const SizedBox(height: 16),
            Text(
              item.transliteration,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.55,
                color: PrayerCastTokens.glyph(context),
              ),
            ),
          ],
          if (showTranslation) ...[
            const SizedBox(height: 14),
            Text(
              item.translation,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                height: 1.55,
                color: PrayerCastTokens.glyphMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom action: a tall tap counter for repeated items, or a single
/// "read, next" button for items read once.
class _ReadingControls extends StatelessWidget {
  const _ReadingControls({
    required this.item,
    required this.reads,
    required this.isLast,
    required this.onTapCount,
    required this.onUndo,
    required this.onNext,
  });

  final AdhkarContent item;
  final int reads;
  final bool isLast;
  final VoidCallback onTapCount;
  final VoidCallback onUndo;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(64),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(
        fontFamily: PrayerCastTheme.bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    if (item.count <= 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          key: AdhkarPageBody.advanceButtonKey,
          style: buttonStyle,
          onPressed: onNext,
          child: Text(isLast ? l10n.adhkarFinish : l10n.adhkarMarkRead),
        ),
      );
    }

    final done = reads >= item.count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: reads > 0 ? onUndo : null,
            tooltip: l10n.dhikrUndo,
            icon: const Icon(Icons.undo_rounded),
            color: PrayerCastTokens.glyph(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              label: '${l10n.adhkarTapToCount}, $reads / ${item.count}',
              excludeSemantics: true,
              button: true,
              onTap: onTapCount,
              child: FilledButton(
                key: AdhkarPageBody.advanceButtonKey,
                style: buttonStyle.copyWith(
                  backgroundColor: done
                      ? const WidgetStatePropertyAll(PrayerCastColors.dawn)
                      : null,
                ),
                onPressed: onTapCount,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.adhkarTapToCount,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$reads / ${item.count}',
                      style: const TextStyle(
                        fontFamily: PrayerCastTheme.displayFont,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: PrayerCastColors.leaf,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adhkarCompleteTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: PrayerCastTheme.displayFont,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: PrayerCastTokens.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adhkarCompleteBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                color: PrayerCastTokens.glyphMuted(context),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.adhkarFinish),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRestart, child: Text(l10n.adhkarReadAgain)),
          ],
        ),
      ),
    );
  }
}

/// Display options for reading, then the speaker schedule for this set.
class _AdhkarSettingsSheet extends ConsumerWidget {
  const _AdhkarSettingsSheet({required this.type});

  final AdhkarType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isMorning = type == AdhkarType.morning;
    final showTranslit = ref.watch(adhkarShowTransliterationProvider);
    final showTranslation = ref.watch(adhkarShowTranslationProvider);
    final scale = ref.watch(adhkarArabicScaleProvider);
    final enabled = ref.watch(adhkarEnabledProvider(type));
    final delay = ref.watch(adhkarDelayProvider(type));
    final coordinator = ref.watch(adhkarDeliveryCoordinatorProvider);

    final labelStyle = TextStyle(
      fontFamily: PrayerCastTheme.bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: PrayerCastTokens.onSurface(context),
    );
    final mutedStyle = TextStyle(
      fontFamily: PrayerCastTheme.bodyFont,
      fontSize: 13,
      height: 1.45,
      color: PrayerCastTokens.glyphMuted(context),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.adhkarShowTransliteration, style: labelStyle),
              value: showTranslit,
              onChanged: (v) => ref
                  .read(adhkarShowTransliterationProvider.notifier)
                  .state = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.adhkarShowTranslation, style: labelStyle),
              value: showTranslation,
              onChanged: (v) =>
                  ref.read(adhkarShowTranslationProvider.notifier).state = v,
            ),
            const SizedBox(height: 8),
            Text(l10n.adhkarTextSize, style: labelStyle),
            Row(
              children: [
                Text('ع', style: TextStyle(fontFamily: PrayerCastTheme.arabicFont, fontSize: 16, color: PrayerCastTokens.glyph(context))),
                Expanded(
                  child: Slider(
                    value: scale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    onChanged: (v) =>
                        ref.read(adhkarArabicScaleProvider.notifier).state = v,
                  ),
                ),
                Text('ع', style: TextStyle(fontFamily: PrayerCastTheme.arabicFont, fontSize: 26, color: PrayerCastTokens.glyph(context))),
              ],
            ),
            const SectionRule(top: 8, bottom: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.adhkarAutoPlaySpeaker, style: labelStyle),
              subtitle: Text(l10n.adhkarAutoPlayHint, style: mutedStyle),
              value: enabled,
              onChanged: (v) => toggleAdhkarEnabled(ref, type, v),
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Text(
                isMorning
                    ? l10n.adhkarDelayAfterFajr(delay)
                    : l10n.adhkarDelayAfterAsr(delay),
                style: labelStyle,
              ),
              Slider(
                value: delay.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                label: isMorning
                    ? l10n.adhkarDelayAfterFajr(delay)
                    : l10n.adhkarDelayAfterAsr(delay),
                onChanged: (v) => updateAdhkarDelay(ref, type, v.round()),
              ),
            ],
            Text(
              isMorning
                  ? l10n.timingGuidanceMorning
                  : l10n.timingGuidanceEvening,
              style: mutedStyle.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: coordinator == null
                    ? null
                    : () => _playNow(context, coordinator),
                icon: const Icon(Icons.speaker_outlined),
                label: Text(l10n.adhkarPlayOnSpeakerNow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playNow(
    BuildContext context,
    AdhkarDeliveryCoordinator coordinator,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await coordinator.testAdhkar(type);
    if (result == AdhkarDeliveryResult.success) return;
    final message = switch (result) {
      AdhkarDeliveryResult.success => '',
      AdhkarDeliveryResult.speakerOffline => l10n.adhkarSpeakerOffline,
      AdhkarDeliveryResult.audioMissing => l10n.adhkarAudioMissing,
      AdhkarDeliveryResult.castFailed => l10n.adhkarPlayFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
