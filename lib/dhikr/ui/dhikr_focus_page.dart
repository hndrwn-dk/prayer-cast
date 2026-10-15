import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/dhikr/data/dhikr_catalog.dart';
import 'package:prayer_cast/dhikr/platform/dhikr_device.dart';
import 'package:prayer_cast/dhikr/ui/dhikr_counter_providers.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

/// One-dhikr-per-screen counter, built to be used without looking:
/// the whole body is the tap target, every tap ticks the phone, reaching
/// the target buzzes twice, the screen stays awake, and on Android the
/// volume buttons count too.
///
/// With [sequence] the steps run in order (after-prayer tasbih) and the
/// page moves to the next step by itself when one is complete.
class DhikrFocusPage extends ConsumerStatefulWidget {
  const DhikrFocusPage({
    super.key,
    required this.steps,
    this.sequence = false,
    this.eyebrow,
  });

  final List<DhikrSpec> steps;
  final bool sequence;
  final String? eyebrow;

  static const ValueKey<String> tapAreaKey = ValueKey<String>('dhikr_tap_area');

  @override
  ConsumerState<DhikrFocusPage> createState() => _DhikrFocusPageState();
}

class _DhikrFocusPageState extends ConsumerState<DhikrFocusPage> {
  static const Duration _advanceDelay = Duration(milliseconds: 700);

  final Map<String, int> _counts = {};
  int _index = 0;
  bool _loaded = false;
  bool _advancing = false;
  bool _volumeKeys = false;
  StreamSubscription<void>? _volumeSub;
  Timer? _advanceTimer;

  DhikrDevice get _device => DhikrDevice.instance;
  DhikrSpec get _step => widget.steps[_index];
  int get _count => _counts[_step.id] ?? 0;
  bool get _sequenceDone =>
      widget.sequence &&
      widget.steps.every((s) => (_counts[s.id] ?? 0) >= s.target);

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_device.setKeepScreenOn(true));
    _volumeSub = _device.volumeTaps.listen((_) => _increment());
    _device.setVolumeKeyCounting(true).then((ok) {
      if (mounted && ok) setState(() => _volumeKeys = true);
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _volumeSub?.cancel();
    unawaited(_device.setVolumeKeyCounting(false));
    unawaited(_device.setKeepScreenOn(false));
    super.dispose();
  }

  Future<void> _load() async {
    final store = ref.read(dhikrCounterStoreProvider);
    for (final s in widget.steps) {
      _counts[s.id] = (await store.get(s.id))?.count ?? 0;
    }
    // A finished sequence starts over: after-prayer dhikr is per prayer.
    if (_sequenceDone) await _resetAll();
    if (widget.sequence) {
      final next = widget.steps.indexWhere(
        (s) => (_counts[s.id] ?? 0) < s.target,
      );
      _index = next < 0 ? 0 : next;
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _increment() {
    if (!_loaded || _advancing || _sequenceDone) return;
    final step = _step;
    final next = _count + 1;
    setState(() => _counts[step.id] = next);
    unawaited(_persist(
      ref.read(dhikrCounterStoreProvider).increment(step.id, target: step.target),
      step.id,
    ));

    if (next == step.target) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        HapticFeedback.heavyImpact,
      );
      if (widget.sequence) _scheduleAdvance();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _scheduleAdvance() {
    _advancing = true;
    _advanceTimer = Timer(_advanceDelay, () {
      if (!mounted) return;
      setState(() {
        _advancing = false;
        if (_index < widget.steps.length - 1) _index++;
      });
    });
  }

  void _undo() {
    if (!_loaded) return;
    _advanceTimer?.cancel();
    _advancing = false;
    // In a sequence, undo at 0 steps back to the previous dhikr.
    if (_count == 0 && widget.sequence && _index > 0) {
      setState(() => _index--);
    }
    final step = _step;
    if (_count == 0) return;
    setState(() => _counts[step.id] = _count - 1);
    HapticFeedback.selectionClick();
    unawaited(_persist(
      ref.read(dhikrCounterStoreProvider).decrement(step.id),
      step.id,
    ));
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dhikrResetConfirmTitle),
        content: Text(l10n.dhikrResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dhikrCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.dhikrReset),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _advanceTimer?.cancel();
    _advancing = false;
    if (widget.sequence) {
      await _resetAll();
      if (mounted) setState(() => _index = 0);
    } else {
      final id = _step.id;
      setState(() => _counts[id] = 0);
      await _persist(ref.read(dhikrCounterStoreProvider).reset(id), id);
    }
  }

  Future<void> _resetAll() async {
    final store = ref.read(dhikrCounterStoreProvider);
    for (final s in widget.steps) {
      _counts[s.id] = 0;
      await _persist(store.reset(s.id), s.id);
    }
    if (mounted) setState(() {});
  }

  /// Writes in the background; the list page re-reads when it returns.
  Future<void> _persist(Future<void> write, String id) async {
    try {
      await write;
    } finally {
      if (mounted) ref.invalidate(dhikrCounterProvider(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ForestScaffold(
      header: EditorialPageHeader(
        eyebrow: widget.eyebrow,
        title: l10n.generalDhikr,
        backTooltip: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
        trailing: widget.sequence && !_sequenceDone
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  l10n.adhkarProgress(_index + 1, widget.steps.length),
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 14,
                    color: PrayerCastTokens.glyphMuted(context),
                  ),
                ),
              )
            : null,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _sequenceDone
              ? _SequenceDone(
                  onRestart: () async {
                    await _resetAll();
                    if (mounted) setState(() => _index = 0);
                  },
                )
              : _buildCounter(context),
      bottom: _loaded && !_sequenceDone ? _buildControls(context) : null,
    );
  }

  Widget _buildCounter(BuildContext context) {
    final l10n = context.l10n;
    final step = _step;
    final count = _count;
    final done = count >= step.target;
    final double progress =
        step.target == 0 ? 0.0 : (count / step.target).clamp(0.0, 1.0).toDouble();

    return Semantics(
      button: true,
      label: '${step.translation}, $count / ${step.target}',
      onTapHint: l10n.adhkarTapToCount,
      onTap: _increment,
      excludeSemantics: true,
      child: GestureDetector(
        key: DhikrFocusPage.tapAreaKey,
        behavior: HitTestBehavior.opaque,
        onTap: _increment,
        child: LayoutBuilder(
          builder: (context, box) {
            final ring = (box.maxWidth * 0.62).clamp(180.0, 280.0).toDouble();
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, box.maxHeight - 24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.sequence) ...[
                      _StepDots(
                        total: widget.steps.length,
                        current: _index,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      step.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: step.arabic.length > 40 ? 24 : 34,
                        height: 1.8,
                        color: PrayerCastTokens.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.transliteration,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: PrayerCastTokens.glyph(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.translation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 14,
                        height: 1.4,
                        color: PrayerCastTokens.glyphMuted(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox.square(
                      dimension: ring,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: progress),
                            duration: const Duration(milliseconds: 160),
                            builder: (context, v, _) =>
                                CircularProgressIndicator(
                              value: v,
                              strokeWidth: 10,
                              strokeCap: StrokeCap.round,
                              backgroundColor: PrayerCastTokens.track(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                done
                                    ? PrayerCastColors.dawn
                                    : PrayerCastColors.leaf,
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontFamily: PrayerCastTheme.displayFont,
                                    fontSize: ring * 0.32,
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                    color: PrayerCastTokens.onSurface(context),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '/ ${step.target}',
                                  style: TextStyle(
                                    fontFamily: PrayerCastTheme.bodyFont,
                                    fontSize: 18,
                                    color: PrayerCastTokens.glyphMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      done && !widget.sequence
                          ? l10n.dhikrTargetReached
                          : l10n.dhikrTapAnywhere,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 13,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                        color: done
                            ? PrayerCastColors.dawn
                            : PrayerCastTokens.glyphMuted(context),
                      ),
                    ),
                    if (_volumeKeys) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.dhikrVolumeKeysHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: PrayerCastTheme.bodyFont,
                          fontSize: 12,
                          color: PrayerCastTokens.glyphMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final l10n = context.l10n;
    final canUndo = _count > 0 || (widget.sequence && _index > 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: canUndo ? _undo : null,
            tooltip: l10n.dhikrUndo,
            icon: const Icon(Icons.undo_rounded),
            iconSize: 26,
            color: PrayerCastTokens.glyph(context),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(l10n.dhikrReset),
            style: TextButton.styleFrom(
              foregroundColor: PrayerCastTokens.glyphMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= current
                    ? PrayerCastColors.leaf
                    : PrayerCastTokens.track(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _SequenceDone extends StatelessWidget {
  const _SequenceDone({required this.onRestart});

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
              l10n.dhikrSequenceDone,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: PrayerCastTheme.displayFont,
                fontSize: 22,
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
            TextButton(
              onPressed: onRestart,
              child: Text(l10n.dhikrStartAgain),
            ),
          ],
        ),
      ),
    );
  }
}
