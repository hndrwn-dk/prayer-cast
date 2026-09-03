import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/soft_pill.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import 'package:prayer_cast/home_delivery/platform/post_notifications_permission.dart';

import '../adzan_voices.dart';
import '../aladhan_client.dart';
import '../indonesia_location.dart';
import '../location_resolver.dart';
import '../prayer_prefs.dart';
import '../prayer_times_providers.dart';
import 'location_disclosure.dart';
import 'notification_disclosure.dart';

/// Premium prayer-time settings: location, method, schedule + voice test.
class PrayerSettingsPage extends ConsumerStatefulWidget {
  const PrayerSettingsPage({
    super.key,
    this.coordinator,
    this.locationResolver = const LocationResolver(),
    this.postNotifications = const PostNotificationsPermission(),
    this.showNotificationDisclosure = showNotificationDisclosureDialog,
  });

  final PrayerDeliveryCoordinator? coordinator;
  final LocationResolving locationResolver;
  final PostNotificationsPermission postNotifications;
  final Future<bool> Function(BuildContext context) showNotificationDisclosure;

  @override
  ConsumerState<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends ConsumerState<PrayerSettingsPage> {
  PrayerPrefs? _draft;
  bool _saving = false;
  bool _loadingSchedule = false;
  bool _detectingLocation = false;
  bool _editingPlace = false;
  bool _scheduleExpanded = false;
  String? _testingPrayer;
  bool _schedulingDryRun = false;
  String? _dryRunStatus;
  bool _dryRunIsError = false;
  String? _pageStatus;
  bool _pageStatusIsError = false;
  String? _scheduleError;
  String? _scheduleMethodName;
  List<NextPrayer> _schedule = const [];
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  bool _controllersReady = false;
  int _lastAladhanMethodId = defaultAladhanMethodId;

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _ensureControllers(PrayerPrefs prefs) {
    if (_controllersReady) return;
    _cityController.text = prefs.city;
    _countryController.text = prefs.country;
    _rememberAladhan(prefs.methodId);
    _controllersReady = true;
  }

  void _rememberAladhan(int methodId) {
    if (!isKemenagMethod(methodId)) {
      _lastAladhanMethodId = methodId;
    }
  }

  Future<void> _refreshSchedule(PrayerPrefs draft) async {
    setState(() {
      _loadingSchedule = true;
      _scheduleError = null;
    });
    try {
      final engine = ref.read(adhanNextPrayerProvider);
      engine.invalidateCache();
      final day = await engine.scheduleForDay(
        prefs: draft,
        day: DateTime.now(),
      );
      if (!mounted) return;
      final fallback = engine.lastFallbackMessage;
      setState(() {
        _schedule = day.slots;
        _scheduleMethodName = day.methodName;
        _loadingSchedule = false;
        if (fallback != null) {
          _pageStatus = context.l10n.kemenagFallback(fallback);
          _pageStatusIsError = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSchedule = false;
        _scheduleError = '$e';
        _schedule = const [];
        _scheduleMethodName = null;
      });
    }
  }

  Future<void> _detectLocation(PrayerPrefs draft) async {
    final alreadyGranted = await widget.locationResolver.hasGrantedPermission();
    if (!alreadyGranted) {
      if (!mounted) return;
      final proceed = await showLocationDisclosureDialog(context);
      if (!proceed) {
        if (mounted) setState(() => _editingPlace = true);
        return;
      }
      if (!mounted) return;
    }
    setState(() {
      _detectingLocation = true;
      _editingPlace = false;
    });
    try {
      final resolved = await widget.locationResolver.resolveCurrent();
      if (!mounted) return;
      _rememberAladhan(draft.methodId);
      final next = draft.copyWith(
        city: resolved.city,
        country: resolved.country,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
        administrativeArea: resolved.administrativeArea,
        methodId: methodIdForLocationDetect(
          country: resolved.country,
          currentMethodId: draft.methodId,
          previousAladhanMethodId: _lastAladhanMethodId,
        ),
      );
      _cityController.text = resolved.city;
      _countryController.text = resolved.country;
      final l10n = context.l10n;
      setState(() {
        _draft = next;
        _pageStatus = l10n.locationResolved(
          '${resolved.city}, ${resolved.country}',
        );
        _pageStatusIsError = false;
      });
      await _refreshSchedule(next);
    } catch (e) {
      if (!mounted) return;
      _setPageStatus(locationErrorMessage(context.l10n, e), error: true);
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPrefs = ref.watch(prayerPrefsProvider);
    final l10n = context.l10n;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return ForestScaffold(
            header: EditorialPageHeader(
              eyebrow: l10n.scheduleEyebrow,
              title: l10n.prayerTimes,
              backTooltip: l10n.back,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            body: asyncPrefs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
              data: (prefs) {
                final draft = _draft ?? prefs;
                _ensureControllers(draft);
                if (_draft == null &&
                    _schedule.isEmpty &&
                    !_loadingSchedule &&
                    _scheduleError == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_refreshSchedule(draft));
                  });
                }

                final visibleSlots = _scheduleExpanded || _schedule.length <= 2
                    ? _schedule
                    : _schedule.take(2).toList();
                final hiddenCount = _schedule.length - visibleSlots.length;

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const ValueKey('prayer_settings_list'),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          InkSurface(
                            borderColor: PrayerCastColors.inkSoft,
                            borderWidth: PrayerCastTheme.cardHairline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: PrayerCastTheme.minTap,
                                  child: FilledButton(
                                    onPressed:
                                        (_detectingLocation || _loadingSchedule)
                                        ? null
                                        : () => _detectLocation(draft),
                                    child: Text(
                                      _detectingLocation
                                          ? l10n.detectingLocation
                                          : l10n.useCurrentLocation,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    PremiumIcons.house(
                                      size: 20,
                                      color: PrayerCastColors.mist,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        draft.displayLocation.isEmpty
                                            ? l10n.noLocationYet
                                            : draft.displayLocation,
                                        style: text.titleMedium,
                                      ),
                                    ),
                                    SoftPill(
                                      label: draft.hasCoordinates
                                          ? l10n.pillGps
                                          : l10n.pillManual,
                                      backgroundColor: PrayerCastColors.canopy,
                                      foregroundColor: PrayerCastColors.mist,
                                    ),
                                  ],
                                ),
                                if (draft.hasCoordinates) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${draft.latitude!.toStringAsFixed(4)}, '
                                    '${draft.longitude!.toStringAsFixed(4)}',
                                    style: text.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  l10n.travelCityHint,
                                  style: text.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(
                                        () => _editingPlace = !_editingPlace,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 40),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _editingPlace
                                          ? l10n.hideCityForm
                                          : l10n.changeCityCountry,
                                    ),
                                  ),
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      children: [
                                        TextField(
                                          controller: _cityController,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          decoration: _fieldDecoration(
                                            l10n.city,
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              _draft = draft.copyWith(
                                                city: v.trim(),
                                                clearCoordinates: true,
                                                clearAdministrativeArea: true,
                                              );
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _countryController,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          decoration: _fieldDecoration(
                                            l10n.country,
                                          ),
                                          onChanged: (v) {
                                            _rememberAladhan(draft.methodId);
                                            final country = v.trim();
                                            setState(() {
                                              _draft = draft.copyWith(
                                                country: country,
                                                methodId:
                                                    methodIdForCountryChange(
                                                      previousCountry:
                                                          draft.country,
                                                      nextCountry: country,
                                                      currentMethodId:
                                                          draft.methodId,
                                                      previousAladhanMethodId:
                                                          _lastAladhanMethodId,
                                                    ),
                                                clearCoordinates: true,
                                                clearAdministrativeArea: true,
                                              );
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  crossFadeState: _editingPlace
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 220),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkSurface(
                            borderColor: PrayerCastColors.inkSoft,
                            borderWidth: PrayerCastTheme.cardHairline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.calculationMethod,
                                  style: text.bodyMedium?.copyWith(
                                    color: PrayerCastColors.dawn,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    DropdownButtonFormField<int>(
                                      key: ValueKey('method-${draft.methodId}'),
                                      initialValue: _methodOrFallback(
                                        draft.methodId,
                                      ),
                                      isExpanded: true,
                                      style: PrayerCastTheme.forestDropdown,
                                      items: [
                                        for (final m in AladhanMethods.common)
                                          DropdownMenuItem(
                                            value: m.id,
                                            child: Text(
                                              _methodLabel(l10n, m),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (id) {
                                        if (id == null) return;
                                        _rememberAladhan(id);
                                        final next = draft.copyWith(
                                          methodId: id,
                                        );
                                        setState(() => _draft = next);
                                        unawaited(_refreshSchedule(next));
                                      },
                                      decoration: _fieldDecoration(null),
                                    ),
                                    if (_isAutoMethod(draft))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 40,
                                        ),
                                        child: IgnorePointer(
                                          child: SoftPill(
                                            label: l10n.pillAuto,
                                            backgroundColor:
                                                PrayerCastColors.canopy,
                                            foregroundColor:
                                                PrayerCastColors.mist,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<PrayerMadhabId>(
                                  key: ValueKey('madhab-${draft.madhabId}'),
                                  initialValue: draft.madhabId,
                                  isExpanded: true,
                                  style: PrayerCastTheme.forestDropdown,
                                  items: [
                                    DropdownMenuItem(
                                      value: PrayerMadhabId.shafi,
                                      child: Text(l10n.madhabShafi),
                                    ),
                                    DropdownMenuItem(
                                      value: PrayerMadhabId.hanafi,
                                      child: Text(l10n.madhabHanafi),
                                    ),
                                  ],
                                  onChanged: (id) {
                                    if (id == null) return;
                                    final next = draft.copyWith(madhabId: id);
                                    setState(() {
                                      _draft = next;
                                      // Asr is below the collapsed Fajr/Dhuhr rows.
                                      _scheduleExpanded = true;
                                    });
                                    unawaited(_refreshSchedule(next));
                                  },
                                  decoration: _fieldDecoration(null),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isKemenagMethod(draft.methodId)
                                      ? l10n.madhabKemenagHint
                                      : l10n.madhabAsrOnlyHint,
                                  style: text.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: PrayerCastTheme.minTap,
                                  child: OutlinedButton(
                                    onPressed:
                                        _loadingSchedule || _detectingLocation
                                        ? null
                                        : () => _refreshSchedule(
                                            draft.copyWith(
                                              city: _cityController.text.trim(),
                                              country: _countryController.text
                                                  .trim(),
                                            ),
                                          ),
                                    child: Text(
                                      _loadingSchedule
                                          ? l10n.fetchingSchedule
                                          : l10n.fetchSchedule,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkSurface(
                            borderColor: PrayerCastColors.inkSoft,
                            borderWidth: PrayerCastTheme.cardHairline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    PremiumIcons.clock(
                                      size: 20,
                                      color: PrayerCastColors.dawn,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n.todaysSchedule,
                                      style: text.titleLarge,
                                    ),
                                  ],
                                ),
                                if (_scheduleMethodName != null &&
                                    _scheduleMethodName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _scheduleMethodName!,
                                    key: const ValueKey('schedule_method_name'),
                                    style: text.bodyMedium?.copyWith(
                                      color: PrayerCastColors.dawn,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  l10n.scheduleVoiceHint,
                                  style: text.bodyMedium,
                                ),
                                if (_scheduleError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _scheduleError!,
                                    style: text.bodyMedium?.copyWith(
                                      color: PrayerCastColors.danger,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (_loadingSchedule)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 28),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (_schedule.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      l10n.scheduleEmptyHint,
                                      style: text.bodyMedium,
                                    ),
                                  )
                                else ...[
                                  for (
                                    var i = 0;
                                    i < visibleSlots.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 28,
                                        color: PrayerCastColors.inkSoft,
                                      ),
                                    PrayerScheduleTile(
                                      prayer: visibleSlots[i],
                                      voiceId: draft.voiceFor(
                                        visibleSlots[i].name,
                                      ),
                                      deliveryMode: draft.deliveryFor(
                                        visibleSlots[i].name,
                                      ),
                                      testing:
                                          _testingPrayer ==
                                          visibleSlots[i].name,
                                      enabled: _testingPrayer == null,
                                      onVoiceChanged: (voiceId) {
                                        setState(() {
                                          _draft = draft.withVoiceFor(
                                            visibleSlots[i].name,
                                            voiceId,
                                          );
                                        });
                                      },
                                      onDeliveryChanged: (mode) {
                                        setState(() {
                                          _draft = draft.withDeliveryFor(
                                            visibleSlots[i].name,
                                            mode,
                                          );
                                        });
                                      },
                                      onTest: () => _testDelivery(
                                        visibleSlots[i].name,
                                        draft,
                                      ),
                                    ),
                                  ],
                                  if (hiddenCount > 0 || _scheduleExpanded) ...[
                                    const SizedBox(height: 8),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          setState(
                                            () => _scheduleExpanded =
                                                !_scheduleExpanded,
                                          );
                                        },
                                        child: Text(
                                          _scheduleExpanded
                                              ? l10n.hide
                                              : l10n.morePrayers(hiddenCount),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PrePrayerAlertCard(
                            minutes: draft.prePrayerAlertMinutes,
                            sound: draft.prePrayerAlertSound,
                            onChanged: (minutes) {
                              setState(() {
                                _draft = draft.copyWith(
                                  prePrayerAlertMinutes: minutes,
                                );
                              });
                            },
                            onSoundChanged: (sound) {
                              setState(() {
                                _draft = draft.copyWith(
                                  prePrayerAlertSound: sound,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _DryRunCard(
                            enabled:
                                widget.coordinator != null &&
                                !_schedulingDryRun &&
                                _testingPrayer == null,
                            statusText: _dryRunStatus,
                            statusIsError: _dryRunIsError,
                            onIn1Minute: () => _scheduleDryRun(
                              PrayerDeliveryCoordinator.dryRunIn1Minute,
                            ),
                            onIn5Minutes: () => _scheduleDryRun(
                              PrayerDeliveryCoordinator.dryRunIn5Minutes,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pageStatus != null)
                      _PageStatusBanner(
                        message: _pageStatus!,
                        isError: _pageStatusIsError,
                      ),
                    _StickySaveBar(
                      saving: _saving,
                      onSave: () => _save(
                        draft.copyWith(
                          city: _cityController.text.trim(),
                          country: _countryController.text.trim(),
                          configured: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _scheduleDryRun(Duration untilAzan) async {
    final coordinator = widget.coordinator;
    final l10n = context.l10n;
    if (coordinator == null) return;
    setState(() => _schedulingDryRun = true);
    try {
      final alreadyGranted = await widget.postNotifications.isGranted();
      if (!alreadyGranted) {
        if (!mounted) return;
        final proceed = await widget.showNotificationDisclosure(context);
        if (proceed && mounted) {
          await widget.postNotifications.request();
        }
      }
      if (!mounted) return;
      final azanAt = await coordinator.scheduleDryRun(untilAzan: untilAzan);
      if (!mounted) return;
      final local = azanAt.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      _setDryRunStatus(l10n.dryRunScheduled('$hh:$mm'), error: false);
    } catch (e) {
      if (!mounted) return;
      _setDryRunStatus(l10n.dryRunFailed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _schedulingDryRun = false);
    }
  }

  Future<void> _testDelivery(String prayerName, PrayerPrefs draft) async {
    final mode = draft.deliveryFor(prayerName);
    final voiceId = draft.voiceFor(prayerName);
    setState(() => _testingPrayer = prayerName);
    final l10n = context.l10n;
    try {
      switch (mode) {
        case PrayerDeliveryMode.beep:
          await ref.read(localPrayerPlayerProvider).playBeep();
          if (!mounted) return;
          _setPageStatus(l10n.beepPlayed, error: false);
        case PrayerDeliveryMode.takbir:
          await ref.read(localPrayerPlayerProvider).playTakbir();
          if (!mounted) return;
          _setPageStatus(l10n.takbirPlayed, error: false);
        case PrayerDeliveryMode.adhanPhone:
          await ref
              .read(localPrayerPlayerProvider)
              .playAdhan(voiceId: voiceId, waitUntilDone: false);
          if (!mounted) return;
          _setPageStatus(
            l10n.adhanPhonePlayed(
              prayerDisplayName(l10n, prayerName),
              voiceDisplayName(l10n, voiceId),
            ),
            error: false,
          );
        case PrayerDeliveryMode.cast:
          await ref
              .read(adzanCastTesterProvider)
              .playOnHomeSpeaker(voiceId: voiceId, prayerName: prayerName);
          if (!mounted) return;
          _setPageStatus(
            l10n.castSent(
              prayerDisplayName(l10n, prayerName),
              voiceDisplayName(l10n, voiceId),
            ),
            error: false,
          );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is AdzanCastTestFailure
          ? castFailureMessage(l10n, e)
          : l10n.phonePlayFailed('$e');
      _setPageStatus(message, error: true);
    } finally {
      if (mounted) setState(() => _testingPrayer = null);
    }
  }

  Future<void> _save(PrayerPrefs prefs) async {
    final l10n = context.l10n;
    final hasPlace = prefs.displayLocation.trim().isNotEmpty;
    if (!prefs.hasCoordinates &&
        (prefs.city.isEmpty || prefs.country.isEmpty || !hasPlace)) {
      _setPageStatus(l10n.needLocationOrCity, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final alreadyGranted = await widget.postNotifications.isGranted();
      if (!alreadyGranted) {
        if (!mounted) return;
        final proceed = await widget.showNotificationDisclosure(context);
        if (proceed && mounted) {
          await widget.postNotifications.request();
        }
      }
      if (!mounted) return;
      await ref.read(prayerPrefsStoreProvider).write(prefs);
      ref.read(adhanNextPrayerProvider).invalidateCache();
      ref.invalidate(prayerPrefsProvider);
      ref.invalidate(nextPrayerSnapshotProvider);
      await widget.coordinator?.retryScheduleAfterPermissionGranted();
      await widget.coordinator?.refreshPrePrayerAlert();
      if (!mounted) return;
      Navigator.of(context).maybePop(prefs);
    } catch (e) {
      if (!mounted) return;
      _setPageStatus(l10n.saveFailed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setDryRunStatus(String message, {required bool error}) {
    setState(() {
      _dryRunStatus = message;
      _dryRunIsError = error;
    });
  }

  void _setPageStatus(String message, {required bool error}) {
    setState(() {
      _pageStatus = message;
      _pageStatusIsError = error;
    });
  }

  static InputDecoration _fieldDecoration(String? label) {
    return PrayerCastTheme.darkField(label);
  }

  static int _methodOrFallback(int id) {
    for (final m in AladhanMethods.common) {
      if (m.id == id) return id;
    }
    return AladhanMethods.common.first.id;
  }

  static String _methodLabel(AppLocalizations l10n, AladhanMethod method) {
    if (isKemenagMethod(method.id)) return l10n.methodKemenag;
    return method.label;
  }

  static bool _isAutoMethod(PrayerPrefs draft) {
    if (isIndonesiaCountry(draft.country)) {
      return isKemenagMethod(draft.methodId);
    }
    return draft.methodId == defaultAladhanMethodId;
  }
}

class _PrePrayerAlertCard extends StatelessWidget {
  const _PrePrayerAlertCard({
    required this.minutes,
    required this.sound,
    required this.onChanged,
    required this.onSoundChanged,
  });

  final int minutes;
  final PrePrayerAlertSound sound;
  final ValueChanged<int> onChanged;
  final ValueChanged<PrePrayerAlertSound> onSoundChanged;

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final text = Theme.of(context).textTheme;
    return Material(
      color: PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId ? 'Pengingat sebelum adzan' : 'Pre-prayer reminder',
              style: text.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isId
                  ? 'Notifikasi beberapa menit sebelum waktu sholat agar Anda bisa bersiap.'
                  : 'A notification a few minutes before prayer time so you can get ready.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(isId ? 'Mati' : 'Off'),
                ),
                ButtonSegment(
                  value: 10,
                  label: Text(isId ? '10 mnt' : '10 min'),
                ),
                ButtonSegment(
                  value: 15,
                  label: Text(isId ? '15 mnt' : '15 min'),
                ),
              ],
              selected: {minutes == 10 || minutes == 15 ? minutes : 0},
              onSelectionChanged: (selected) {
                onChanged(selected.first);
              },
            ),
            if (minutes > 0) ...[
              const SizedBox(height: 12),
              Text(
                isId ? 'Suara pengingat' : 'Reminder sound',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<PrePrayerAlertSound>(
                segments: [
                  ButtonSegment(
                    value: PrePrayerAlertSound.beep,
                    label: Text(isId ? 'Ketuk' : 'Beep'),
                  ),
                  ButtonSegment(
                    value: PrePrayerAlertSound.takbir,
                    label: Text(isId ? 'Takbir' : 'Takbir'),
                  ),
                ],
                selected: {sound},
                onSelectionChanged: (selected) {
                  onSoundChanged(selected.first);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DryRunCard extends StatefulWidget {
  const _DryRunCard({
    required this.enabled,
    required this.onIn1Minute,
    required this.onIn5Minutes,
    this.statusText,
    this.statusIsError = false,
  });

  final bool enabled;
  final VoidCallback onIn1Minute;
  final VoidCallback onIn5Minutes;
  final String? statusText;
  final bool statusIsError;

  @override
  State<_DryRunCard> createState() => _DryRunCardState();
}

class _DryRunCardState extends State<_DryRunCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _DryRunCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statusText != null &&
        widget.statusText != oldWidget.statusText) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return InkSurface(
      borderColor: PrayerCastColors.inkSoft,
      borderWidth: PrayerCastTheme.cardHairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('dry_run_toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.dryRunTitle, style: text.titleLarge),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: PremiumIcons.caretRight(
                      size: 18,
                      color: PrayerCastColors.mistDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Text(l10n.dryRunHint, style: text.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: PrayerCastTheme.minTap,
                    child: OutlinedButton(
                      key: const ValueKey('dry_run_1m'),
                      onPressed: widget.enabled ? widget.onIn1Minute : null,
                      child: Text(l10n.dryRunIn1Minute),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: PrayerCastTheme.minTap,
                    child: OutlinedButton(
                      key: const ValueKey('dry_run_5m'),
                      onPressed: widget.enabled ? widget.onIn5Minutes : null,
                      child: Text(l10n.dryRunIn5Minutes),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.statusText != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.statusText!,
                key: const ValueKey('dry_run_status'),
                style: text.bodyMedium?.copyWith(
                  color: widget.statusIsError
                      ? PrayerCastColors.dangerSoft
                      : PrayerCastColors.mist,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PageStatusBanner extends StatelessWidget {
  const _PageStatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        message,
        key: const ValueKey('prayer_settings_status'),
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(
          color: isError ? PrayerCastColors.dangerSoft : PrayerCastColors.leaf,
        ),
      ),
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  const _StickySaveBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PrayerCastColors.ink,
        border: const Border(top: BorderSide(color: PrayerCastColors.inkSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          height: PrayerCastTheme.minTap,
          width: double.infinity,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(saving ? l10n.saving : l10n.save),
          ),
        ),
      ),
    );
  }
}

class PrayerScheduleTile extends StatelessWidget {
  const PrayerScheduleTile({
    super.key,
    required this.prayer,
    required this.voiceId,
    required this.deliveryMode,
    required this.testing,
    required this.enabled,
    required this.onVoiceChanged,
    required this.onDeliveryChanged,
    required this.onTest,
  });

  final NextPrayer prayer;
  final String voiceId;
  final PrayerDeliveryMode deliveryMode;
  final bool testing;
  final bool enabled;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<PrayerDeliveryMode> onDeliveryChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final t = prayer.scheduledAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final isFajr = prayer.name == 'fajr';
    final showVoice = deliveryMode.usesVoice;

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KeyedSubtree(
              key: ValueKey('prayer-icon-${prayer.name}'),
              child: PremiumIcons.forPrayer(
                prayer.name,
                size: 22,
                color: PrayerCastColors.dawn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                prayerDisplayName(l10n, prayer.name),
                style: text.titleMedium,
              ),
            ),
            Text(
              '$hh:$mm',
              style: text.headlineMedium?.copyWith(
                fontSize: 26,
                color: scheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<PrayerDeliveryMode>(
                key: ValueKey('delivery-${prayer.name}-${deliveryMode.name}'),
                initialValue: deliveryMode,
                isExpanded: true,
                style: PrayerCastTheme.forestDropdown,
                dropdownColor: scheme.surfaceContainerHigh,
                items: [
                  for (final mode in PrayerDeliveryMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(
                        deliveryDisplayName(l10n, mode),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled
                    ? (mode) {
                        if (mode == null) return;
                        onDeliveryChanged(mode);
                      }
                    : null,
                decoration: _PrayerSettingsPageState._fieldDecoration(null)
                    .copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: enabled && !testing ? onTest : null,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: PrayerCastTheme.minTap,
                  height: PrayerCastTheme.minTap,
                  child: Center(
                    child: testing
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.primary,
                            ),
                          )
                        : PremiumIcons.speaker(
                            size: 24,
                            color: enabled
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showVoice) ...[
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('voice-${prayer.name}-$voiceId'),
                initialValue: voiceId,
                isExpanded: true,
                style: PrayerCastTheme.forestDropdown,
                dropdownColor: scheme.surfaceContainerHigh,
                items: [
                  for (final voice in AdzanVoices.all)
                    DropdownMenuItem(
                      value: voice.id,
                      child: Text(
                        voiceDisplayName(l10n, voice.id),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled
                    ? (id) {
                        if (id == null) return;
                        onVoiceChanged(id);
                      }
                    : null,
                decoration: _PrayerSettingsPageState._fieldDecoration(null)
                    .copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
              ),
              if (isFajr)
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: IgnorePointer(
                    child: SoftPill(
                      label: l10n.pillFajrOnly,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
