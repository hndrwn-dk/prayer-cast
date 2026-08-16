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

  bool get _saving => _savingDeviceId != null;
  bool get _busy => _saving || _removing;

  Future<void> _select(CastReceiver receiver) async {
    if (_busy) return;
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

  void _showIpDebug(CastReceiver receiver) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.speakerIpDebug(receiver.host.address))),
    );
  }

  void _rescan() {
    if (_busy) return;
    ref.read(speakerScanEpochProvider.notifier).state++;
  }

  Future<void> _confirmRemoveHomeSpeaker() async {
    if (_busy) return;
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
                Text(
                  l10n.removeHomeSpeakerConfirmBody,
                  style: text.bodyMedium,
                ),
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
    if (confirmed != true || !mounted) return;
    await _clearHomeSpeaker();
  }

  Future<void> _clearHomeSpeaker() async {
    final l10n = context.l10n;
    setState(() => _removing = true);
    try {
      await ref.read(homeOnboardingProvider).clearHomeSpeaker();
      ref.invalidate(savedHomeSpeakerProvider);
      ref.invalidate(homePresenceProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeSpeakerRemoved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.speakerSaveFailed('$e'))));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedHomeSpeakerProvider);
    final discovery = ref.watch(speakerDiscoveryProvider);
    final l10n = context.l10n;
    final savedSpeaker = saved.asData?.value;
    final selectedId = savedSpeaker?.deviceId;

    final isInitialLoading = discovery.isLoading && !discovery.hasValue;
    final isRefreshing = discovery.isLoading && discovery.hasValue;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return ForestScaffold(
        header: EditorialPageHeader(
          eyebrow: l10n.deviceEyebrow,
          title: l10n.speakerSetupTitle,
          backTooltip: l10n.back,
          onBack: _busy ? null : () => Navigator.of(context).maybePop(),
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
              if (savedSpeaker != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: InkSurface(
                    key: const ValueKey('saved_home_speaker_card'),
                    color: PrayerCastColors.canopyDeep,
                    borderColor: PrayerCastColors.dawn,
                    borderWidth: 1.4,
                    borderRadius: 14,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          savedSpeaker.displayName,
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const ValueKey('remove_home_speaker'),
                          onPressed: _busy ? null : _confirmRemoveHomeSpeaker,
                          child: Text(l10n.removeHomeSpeaker),
                        ),
                      ],
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
                            : discovery.hasValue
                            ? l10n.speakersFound(
                                filterSpeakerCastTargets(
                                  discovery.requireValue.devices,
                                  (d) => d.friendlyName,
                                ).length,
                              )
                            : l10n.speakersFound(0),
                        style: text.titleMedium,
                      ),
                    ),
                    Tooltip(
                      message: l10n.scanAgain,
                      child: Material(
                        color: PrayerCastColors.canopy,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: isInitialLoading || isRefreshing || _busy
                              ? null
                              : _rescan,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: isRefreshing
                                  ? const CastScanSpinner(
                                      size: 18,
                                      strokeWidth: 2.2,
                                      color: PrayerCastColors.mist,
                                      trackColor: PrayerCastColors.inkSoft,
                                      pulse: false,
                                    )
                                  : Opacity(
                                      opacity: isInitialLoading ? 0.35 : 1,
                                      child: PremiumIcons.refresh(
                                        size: 22,
                                        color: PrayerCastColors.mist,
                                      ),
                                    ),
                            ),
                          ),
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
                    final speakers = filterSpeakerCastTargets(
                      result.devices,
                      (d) => d.friendlyName,
                    );
                    if (speakers.isEmpty) {
                      final onlyTvs = result.devices.isNotEmpty;
                      return _EmptyState(
                        guidance: onlyTvs
                            ? l10n.speakerOnlyTvsFound
                            : l10n.noSpeakersFoundGuidance,
                        onRetry: _rescan,
                      );
                    }
                    return _SpeakerList(
                      speakers: speakers,
                      selectedId: selectedId,
                      savingDeviceId: _savingDeviceId,
                      saveSucceeded: _saveSucceeded,
                      enabled: !_busy,
                      onSelect: _select,
                      onLongPress: _showIpDebug,
                    );
                  },
                ),
              ),
            ],
          ),
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
    required this.onSelect,
    required this.onLongPress,
  });

  final List<CastReceiver> speakers;
  final String? selectedId;
  final String? savingDeviceId;
  final bool saveSucceeded;
  final bool enabled;
  final ValueChanged<CastReceiver> onSelect;
  final ValueChanged<CastReceiver> onLongPress;

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
          onTap: () => onSelect(device),
          onLongPress: () => onLongPress(device),
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
    required this.onTap,
    required this.onLongPress,
  });

  final CastReceiver receiver;
  final bool selected;
  final bool saving;
  final bool savedJustNow;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final highlight = selected || savedJustNow;
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

    return Opacity(
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
              if (saving)
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
  }
}
