import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../delivery/cast_client.dart';
import '../delivery/cast_device_kind.dart';
import 'home_setup_providers.dart';
import 'icons/premium_icons.dart';
import 'theme/prayer_cast_colors.dart';
import 'theme/prayer_cast_theme.dart';
import 'widgets/cast_scan_spinner.dart';
import 'widgets/editorial_chrome.dart';
import 'widgets/speaker_search_pulse.dart';

/// Cast speaker onboarding: scan LAN, pick home target, save Signal A + B.
class SpeakerSetupPage extends ConsumerStatefulWidget {
  const SpeakerSetupPage({super.key});

  @override
  ConsumerState<SpeakerSetupPage> createState() => _SpeakerSetupPageState();
}

class _SpeakerSetupPageState extends ConsumerState<SpeakerSetupPage> {
  String? _savingDeviceId;
  bool _saveSucceeded = false;
  bool _removing = false;
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  bool get _saving => _savingDeviceId != null;
  bool get _busy => _saving || _removing;

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _enterSelect() {
    if (_busy) return;
    setState(() {
      _selecting = true;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(CastReceiver receiver) {
    setState(() {
      if (_selectedIds.contains(receiver.deviceId)) {
        _selectedIds.remove(receiver.deviceId);
      } else {
        _selectedIds.add(receiver.deviceId);
      }
    });
  }

  Future<void> _select(CastReceiver receiver) async {
    if (_busy) return;
    if (_selecting) {
      _toggleSelected(receiver);
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _savingDeviceId = receiver.deviceId;
      _saveSucceeded = false;
    });
    try {
      await ref.read(homeOnboardingProvider).saveHomeSpeaker(receiver);
      ref.invalidate(savedHomeSpeakerProvider);
      if (!mounted) return;
      setState(() => _saveSucceeded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speakerSaved(receiver.friendlyName))),
      );
      // Brief beat so the row checkmark / progress is visible before pop.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      Navigator.of(context).maybePop(receiver);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.speakerSaveFailed('$e'))));
      setState(() {
        _savingDeviceId = null;
        _saveSucceeded = false;
      });
    }
  }

  void _onLongPress(CastReceiver receiver) {
    if (_busy) return;
    if (_selecting) {
      _toggleSelected(receiver);
      return;
    }
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.speakerIpDebug(receiver.host.address))),
    );
  }

  void _rescan() {
    if (_busy || _selecting) return;
    ref.read(hiddenSpeakerIdsProvider.notifier).state = const {};
    ref.read(speakerScanEpochProvider.notifier).state++;
  }

  Future<bool> _confirmUnsaveHomeSpeaker() async {
    if (_busy) return false;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: PrayerCastColors.ink.withValues(alpha: 0.72),
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        return Dialog(
          key: const ValueKey('remove_home_speaker_dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: InkSurface(
            borderColor: PrayerCastColors.inkSoft,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.removeHomeSpeakerConfirmTitle,
                  style: text.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(l10n.removeHomeSpeakerConfirmBody, style: text.bodyMedium),
                const SizedBox(height: 20),
                SizedBox(
                  height: PrayerCastTheme.minTap,
                  child: FilledButton(
                    key: const ValueKey('remove_home_speaker_confirm'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.removeHomeSpeakerConfirm),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: PrayerCastTheme.minTap,
                  child: TextButton(
                    key: const ValueKey('remove_home_speaker_cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.removeHomeSpeakerCancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return false;
    return _clearHomeSpeaker();
  }

  Future<bool> _clearHomeSpeaker() async {
    final l10n = context.l10n;
    setState(() => _removing = true);
    try {
      await ref.read(homeOnboardingProvider).clearHomeSpeaker();
      ref.invalidate(savedHomeSpeakerProvider);
      ref.invalidate(homePresenceProvider);
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeSpeakerRemoved)));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.speakerSaveFailed('$e'))));
      return false;
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _addHidden(Set<String> ids) {
    if (ids.isEmpty) return;
    ref.read(hiddenSpeakerIdsProvider.notifier).state = {
      ...ref.read(hiddenSpeakerIdsProvider),
      ...ids,
    };
  }

  Future<bool> _persistHidden(Set<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      await ref.read(homeOnboardingProvider).removeDevicesFromCachedScan(ids);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.speakerSaveFailed('$e'))),
      );
      return false;
    }
  }

  Future<bool> _onSwipeDelete(CastReceiver receiver, String? savedId) async {
    if (_busy || _selecting) return false;
    if (savedId != null && savedId == receiver.deviceId) {
      await _confirmUnsaveHomeSpeaker();
      return false;
    }
    return _persistHidden({receiver.deviceId});
  }

  void _onSwipedAway(CastReceiver receiver) {
    _addHidden({receiver.deviceId});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.speakerHiddenUntilRescan)),
    );
  }

  Future<void> _deleteSelected(String? savedId) async {
    if (_busy || _selectedIds.isEmpty) return;
    final selected = Set<String>.from(_selectedIds);
    final unsaving = savedId != null && selected.contains(savedId);
    if (unsaving) {
      final ok = await _confirmUnsaveHomeSpeaker();
      if (!ok || !mounted) return;
    }
    final scanned = {
      for (final id in selected)
        if (id != savedId) id,
    };
    if (scanned.isNotEmpty) {
      setState(() => _removing = true);
      final persisted = await _persistHidden(scanned);
      if (mounted) setState(() => _removing = false);
      if (!persisted || !mounted) return;
      _addHidden(scanned);
      if (!unsaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.speakerHiddenUntilRescan)),
        );
      }
    }
    if (mounted) _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedHomeSpeakerProvider);
    final discovery = ref.watch(speakerDiscoveryProvider);
    final hiddenIds = ref.watch(hiddenSpeakerIdsProvider);
    final l10n = context.l10n;
    final savedSpeaker = saved.asData?.value;
    final selectedId = savedSpeaker?.deviceId;

    final isInitialLoading = discovery.isLoading && !discovery.hasValue;
    final isRefreshing = discovery.isLoading && discovery.hasValue;
    final visibleSpeakers = discovery.hasValue
        ? filterSpeakerCastTargets(
            discovery.requireValue.devices,
            (d) => d.friendlyName,
          ).where((d) => !hiddenIds.contains(d.deviceId)).toList()
        : const <CastReceiver>[];
    final showSelect = visibleSpeakers.isNotEmpty && !isInitialLoading;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return ForestScaffold(
            header: EditorialPageHeader(
              eyebrow: l10n.deviceEyebrow,
              title: _selecting
                  ? l10n.speakersSelected(_selectedIds.length)
                  : l10n.speakerSetupTitle,
              backTooltip: _selecting
                  ? l10n.removeHomeSpeakerCancel
                  : l10n.back,
              onBack: _busy
                  ? null
                  : _selecting
                  ? _exitSelect
                  : () => Navigator.of(context).maybePop(),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
                  child: Text(l10n.speakerSetupIntro, style: text.bodyLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                  child: Text(
                    l10n.speakerGroupDelayHint,
                    key: const ValueKey('speaker_group_delay_hint'),
                    style: text.bodyMedium?.copyWith(
                      color: PrayerCastColors.mistDeep,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isInitialLoading || isRefreshing
                              ? l10n.scanning
                              : l10n.speakersFound(visibleSpeakers.length),
                          style: text.titleMedium,
                        ),
                      ),
                      if (showSelect) ...[
                        _CircleIconButton(
                          buttonKey: const ValueKey('speaker_select_mode'),
                          tooltip: l10n.selectSpeakers,
                          onTap: isRefreshing || _busy
                              ? null
                              : _selecting
                              ? _exitSelect
                              : _enterSelect,
                          child: PremiumIcons.trash(
                            size: 22,
                            color: _selecting
                                ? PrayerCastColors.dawnSoft
                                : PrayerCastColors.mist,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _CircleIconButton(
                        tooltip: l10n.scanAgain,
                        onTap:
                            isInitialLoading ||
                                isRefreshing ||
                                _busy ||
                                _selecting
                            ? null
                            : _rescan,
                        child: isRefreshing
                            ? const CastScanSpinner(
                                size: 18,
                                strokeWidth: 2.2,
                                color: PrayerCastColors.mist,
                                trackColor: PrayerCastColors.inkSoft,
                                pulse: false,
                              )
                            : Opacity(
                                opacity: isInitialLoading || _selecting
                                    ? 0.35
                                    : 1,
                                child: PremiumIcons.refresh(
                                  size: 22,
                                  color: PrayerCastColors.mist,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: discovery.when(
                    skipLoadingOnReload: true,
                    skipError: true,
                    loading: () => const _ScanningState(),
                    error: (error, _) => _ErrorState(
                      message: l10n.speakerScanFailed('$error'),
                      showOpenSettings: _looksLikePermissionError(error),
                      onRetry: _rescan,
                    ),
                    data: (result) {
                      if (visibleSpeakers.isEmpty) {
                        final onlyTvs = result.devices
                            .where((d) => !hiddenIds.contains(d.deviceId))
                            .isNotEmpty;
                        return _EmptyState(
                          guidance: onlyTvs
                              ? l10n.speakerOnlyTvsFound
                              : l10n.noSpeakersFoundGuidance,
                          onRetry: _rescan,
                        );
                      }
                      return _SpeakerList(
                        speakers: visibleSpeakers,
                        selectedId: selectedId,
                        savingDeviceId: _savingDeviceId,
                        saveSucceeded: _saveSucceeded,
                        enabled: !_busy,
                        selecting: _selecting,
                        checkedIds: _selectedIds,
                        onSelect: _select,
                        onLongPress: _onLongPress,
                        onSwipeDelete: (receiver) =>
                            _onSwipeDelete(receiver, selectedId),
                        onSwipedAway: _onSwipedAway,
                      );
                    },
                  ),
                ),
              ],
            ),
            bottom: _selecting && showSelect
                ? _SelectActionBar(
                    count: _selectedIds.length,
                    enabled: !_busy && _selectedIds.isNotEmpty,
                    onDelete: () => _deleteSelected(selectedId),
                    onCancel: _busy ? null : _exitSelect,
                  )
                : null,
          );
        },
      ),
    );
  }
}

bool _looksLikePermissionError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('permission') ||
      msg.contains('denied') ||
      msg.contains('local network') ||
      msg.contains('localnetwork');
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.buttonKey,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: buttonKey,
        color: PrayerCastColors.canopy,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _SelectActionBar extends StatelessWidget {
  const _SelectActionBar({
    required this.count,
    required this.enabled,
    required this.onDelete,
    required this.onCancel,
  });

  final int count;
  final bool enabled;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkSurface(
        key: const ValueKey('speaker_select_bar'),
        color: PrayerCastColors.canopyDeep,
        borderColor: PrayerCastColors.inkSoft,
        borderRadius: 14,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.speakersSelected(count), style: text.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: PrayerCastTheme.minTap,
                    child: TextButton(
                      key: const ValueKey('speaker_select_cancel'),
                      onPressed: onCancel,
                      child: Text(l10n.removeHomeSpeakerCancel),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: PrayerCastTheme.minTap,
                    child: FilledButton(
                      key: const ValueKey('speaker_select_delete'),
                      onPressed: enabled ? onDelete : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: PrayerCastColors.danger,
                        foregroundColor: PrayerCastColors.surfaceRaised,
                      ),
                      child: Text(l10n.deleteSpeaker),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanningState extends StatelessWidget {
  const _ScanningState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Center(
      key: const ValueKey('speaker_scanning_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpeakerSearchPulse(size: 112),
            const SizedBox(height: 20),
            Text(
              l10n.searchingForSpeakers,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.guidance, required this.onRetry});

  final String guidance;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Center(
      key: const ValueKey('speaker_empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: InkSurface(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          borderColor: PrayerCastColors.inkSoft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconWell(
                size: 56,
                radius: 16,
                child: PremiumIcons.speakerSlash(
                  size: 28,
                  color: PrayerCastColors.mistDeep,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noSpeakersFoundTitle,
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                guidance,
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('speaker_scan_retry'),
                onPressed: onRetry,
                child: Text(l10n.speakerScanRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.showOpenSettings,
    required this.onRetry,
  });

  final String message;
  final bool showOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Center(
      key: const ValueKey('speaker_error_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: InkSurface(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          borderColor: PrayerCastColors.inkSoft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconWell(
                size: 56,
                radius: 16,
                child: PremiumIcons.wifiSlash(
                  size: 28,
                  color: PrayerCastColors.mistDeep,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    key: const ValueKey('speaker_scan_retry'),
                    onPressed: onRetry,
                    child: Text(l10n.speakerScanRetry),
                  ),
                  if (showOpenSettings)
                    OutlinedButton(
                      onPressed: () => openAppSettings(),
                      child: Text(l10n.openLocalNetworkSettings),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakerList extends StatelessWidget {
  const _SpeakerList({
    required this.speakers,
    required this.selectedId,
    required this.savingDeviceId,
    required this.saveSucceeded,
    required this.enabled,
    required this.selecting,
    required this.checkedIds,
    required this.onSelect,
    required this.onLongPress,
    required this.onSwipeDelete,
    required this.onSwipedAway,
  });

  final List<CastReceiver> speakers;
  final String? selectedId;
  final String? savingDeviceId;
  final bool saveSucceeded;
  final bool enabled;
  final bool selecting;
  final Set<String> checkedIds;
  final ValueChanged<CastReceiver> onSelect;
  final ValueChanged<CastReceiver> onLongPress;
  final Future<bool> Function(CastReceiver receiver) onSwipeDelete;
  final ValueChanged<CastReceiver> onSwipedAway;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('speaker_list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: speakers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final device = speakers[index];
        final selected = selectedId != null && selectedId == device.deviceId;
        final isSavingRow = savingDeviceId == device.deviceId;
        return _SpeakerTile(
          receiver: device,
          selected: selected,
          saving: isSavingRow && !saveSucceeded,
          savedJustNow: isSavingRow && saveSucceeded,
          enabled: enabled,
          selecting: selecting,
          checked: checkedIds.contains(device.deviceId),
          swipeEnabled: enabled && !selecting,
          onTap: () => onSelect(device),
          onLongPress: () => onLongPress(device),
          onSwipeDelete: () => onSwipeDelete(device),
          onSwipedAway: () => onSwipedAway(device),
        );
      },
    );
  }
}

class _SpeakerTile extends StatelessWidget {
  const _SpeakerTile({
    required this.receiver,
    required this.selected,
    required this.saving,
    required this.savedJustNow,
    required this.enabled,
    required this.selecting,
    required this.checked,
    required this.swipeEnabled,
    required this.onTap,
    required this.onLongPress,
    required this.onSwipeDelete,
    required this.onSwipedAway,
  });

  final CastReceiver receiver;
  final bool selected;
  final bool saving;
  final bool savedJustNow;
  final bool enabled;
  final bool selecting;
  final bool checked;
  final bool swipeEnabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() onSwipeDelete;
  final VoidCallback onSwipedAway;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final highlight = selected || savedJustNow || (selecting && checked);
    final borderColor = highlight
        ? PrayerCastColors.dawn
        : PrayerCastColors.inkSoft;
    final borderWidth = highlight ? 1.4 : 1.0;
    final dimOthers = !enabled && !saving && !savedJustNow;
    final group = looksLikeCastGroup(receiver.friendlyName);
    final statusText = saving
        ? l10n.saving
        : group
        ? l10n.speakerGroupMayDelay
        : l10n.reachableNow;

    final tile = Opacity(
      opacity: dimOthers ? 0.45 : 1,
      child: InkSurface(
        color: PrayerCastColors.canopyDeep,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabled: enabled,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              if (selecting) ...[
                _SelectMark(checked: checked, deviceId: receiver.deviceId),
                const SizedBox(width: 12),
              ],
              IconWell(
                size: 44,
                radius: 12,
                child: PremiumIcons.speaker(
                  size: 24,
                  color: PrayerCastColors.mist,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receiver.friendlyName, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: text.bodyMedium?.copyWith(
                        color: saving
                            ? PrayerCastColors.dawnSoft
                            : PrayerCastColors.mistDeep,
                      ),
                    ),
                  ],
                ),
              ),
              if (selecting)
                const SizedBox.shrink()
              else if (saving)
                const CastScanSpinner(
                  size: 22,
                  strokeWidth: 2.4,
                  color: PrayerCastColors.mist,
                  trackColor: PrayerCastColors.inkSoft,
                  pulse: false,
                )
              else if (savedJustNow || selected)
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: PrayerCastColors.leaf,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: PremiumIcons.check(
                    size: 16,
                    color: PrayerCastColors.surfaceRaised,
                  ),
                )
              else
                PremiumIcons.caretRight(
                  size: 22,
                  color: PrayerCastColors.mistDeep,
                ),
            ],
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Dismissible(
        key: ValueKey('speaker_dismiss_${receiver.deviceId}'),
        direction: swipeEnabled
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: ColoredBox(
          color: PrayerCastColors.danger,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(l10n.deleteSpeaker, style: text.labelLarge),
            ),
          ),
        ),
        confirmDismiss: (_) => onSwipeDelete(),
        onDismissed: (_) => onSwipedAway(),
        child: KeyedSubtree(
          key: ValueKey('speaker_tile_${receiver.deviceId}'),
          child: tile,
        ),
      ),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.checked, required this.deviceId});

  final bool checked;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('speaker_check_$deviceId'),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? PrayerCastColors.leaf : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? PrayerCastColors.leaf : PrayerCastColors.mistDeep,
          width: 1.4,
        ),
      ),
      child: checked
          ? PremiumIcons.check(size: 14, color: PrayerCastColors.surfaceRaised)
          : null,
    );
  }
}
