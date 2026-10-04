import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_tokens.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/soft_pill.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';

import '../adzan_voices.dart';
import '../aladhan_client.dart';
import '../indonesia_location.dart';
import '../location_resolver.dart';
import '../prayer_prefs.dart';
import '../prayer_times_providers.dart';
import 'location_disclosure.dart';

enum PrayerSettingsFocus { none, delivery, reminders }

/// Premium prayer-time settings: location, method, schedule + voice test.
class PrayerSettingsPage extends ConsumerStatefulWidget {
  const PrayerSettingsPage({
    super.key,
    this.coordinator,
    this.locationResolver = const LocationResolver(),
    this.focus = PrayerSettingsFocus.none,
    this.onSaved,
  });

  static const deliverySectionKey = ValueKey<String>(
    'prayer_settings_delivery_section',
  );
  static const remindersSectionKey = ValueKey<String>(
    'prayer_settings_reminders_section',
  );

  final PrayerDeliveryCoordinator? coordinator;
  final LocationResolving locationResolver;
  final PrayerSettingsFocus focus;
  final VoidCallback? onSaved;

  @override
  ConsumerState<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends ConsumerState<PrayerSettingsPage> {
  PrayerPrefs? _draft;
  PrayerPrefs? _lastSaved;
  bool _saving = false;
  bool _loadingSchedule = false;
  bool _detectingLocation = false;
  bool _editingPlace = false;
  bool _scheduleExpanded = false;
  String? _testingPrayer;
  String? _pageStatus;
  bool _pageStatusIsError = false;
  String? _scheduleError;
  String? _scheduleMethodName;
  List<NextPrayer> _schedule = const [];
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  bool _controllersReady = false;
  int _lastAladhanMethodId = defaultAladhanMethodId;
  Timer? _saveDebounce;
  final ScrollController _focusScroll = ScrollController();
  bool _didScrollToFocus = false;
  bool _focusScrollPending = false;
  int _focusScrollAttempts = 0;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _focusScroll.dispose();
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
    _lastSaved ??= prefs;
    _draft ??= prefs;
  }

  void _updateDraft(PrayerPrefs Function(PrayerPrefs current) update) {
    final current = _draft ?? ref.read(prayerPrefsProvider).asData?.value;
    if (current == null) return;
    final next = update(current);
    setState(() => _draft = next);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraft(popAfter: false));
    });
  }

  /// Fields that require re-arming the exact alarm / pre-alert / iqamah.
  static bool _affectsSchedule(PrayerPrefs a, PrayerPrefs b) {
    if (a.city != b.city ||
        a.country != b.country ||
        a.methodId != b.methodId ||
        a.madhabId != b.madhabId ||
        a.latitude != b.latitude ||
        a.longitude != b.longitude ||
        a.administrativeArea != b.administrativeArea) {
      return true;
    }
    if (a.defaultDeliveryMode != b.defaultDeliveryMode) return true;
    if (!_mapEquals(a.deliveryByPrayer, b.deliveryByPrayer)) return true;
    if (!_mapEquals(
      a.iqamahMinutesByPrayer.map((k, v) => MapEntry(k, '$v')),
      b.iqamahMinutesByPrayer.map((k, v) => MapEntry(k, '$v')),
    )) {
      return true;
    }
    if (a.prePrayerAlertMinutes != b.prePrayerAlertMinutes) return true;
    if (a.prePrayerAlertSound != b.prePrayerAlertSound) return true;
    if (a.iqamahSound != b.iqamahSound) return true;
    return false;
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
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

    return Builder(
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return ForestScaffold(
          header: EditorialPageHeader(
            eyebrow: l10n.scheduleEyebrow,
            title: l10n.prayerTimes,
            backTooltip: l10n.back,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          body: Builder(
            builder: (context) {
              // Keep showing the last prefs while an autosave reloads the
              // FutureProvider — otherwise the whole page flashes a spinner
              // and SegmentedButton / Switch taps look dead.
              final prefs = asyncPrefs.asData?.value ?? asyncPrefs.value;
              if (prefs == null) {
                if (asyncPrefs.hasError) {
                  return Center(
                    child: Text(l10n.loadFailed('${asyncPrefs.error}')),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }
              final needsScheduleKick =
                  _draft == null &&
                  _schedule.isEmpty &&
                  !_loadingSchedule &&
                  _scheduleError == null;
              final draft = _draft ?? prefs;
              _ensureControllers(draft);
              _scheduleFocusScroll();
              if (needsScheduleKick) {
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
                      // Delivery and reminders sit past the first screen.
                      // A lazy list leaves those keys unbuilt, so
                      // ensureVisible has nothing to scroll. Cache the
                      // whole form when a section was requested.
                      controller: widget.focus == PrayerSettingsFocus.none
                          ? null
                          : _focusScroll,
                      cacheExtent: widget.focus == PrayerSettingsFocus.none
                          ? null
                          : 1000000,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  PremiumIcons.house(
                                    size: 20,
                                    color: PrayerCastTokens.glyph(context),
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
                                    backgroundColor:
                                        PrayerCastColors.canopyQuiet,
                                    foregroundColor:
                                        PrayerCastColors.surfaceRaised,
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
                              Text(l10n.travelCityHint, style: text.bodySmall),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed:
                                      (_detectingLocation || _loadingSchedule)
                                      ? null
                                      : () => _detectLocation(draft),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 40),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _detectingLocation
                                        ? l10n.detectingLocation
                                        : l10n.useCurrentLocation,
                                  ),
                                ),
                              ),
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
                                          context,
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
                                          context,
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
                        const SectionRule(),
                        Column(
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
                                    style: PrayerCastTokens.fieldValue(context),
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
                                      final next = draft.copyWith(methodId: id);
                                      setState(() => _draft = next);
                                      unawaited(_refreshSchedule(next));
                                    },
                                    decoration: _fieldDecoration(context, null),
                                  ),
                                  if (_isAutoMethod(draft))
                                    Padding(
                                      padding: const EdgeInsets.only(right: 40),
                                      child: IgnorePointer(
                                        child: SoftPill(
                                          label: l10n.pillAuto,
                                          backgroundColor:
                                              PrayerCastColors.canopyQuiet,
                                          foregroundColor:
                                              PrayerCastColors.surfaceRaised,
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
                                style: PrayerCastTokens.fieldValue(context),
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
                                decoration: _fieldDecoration(context, null),
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
                        const SectionRule(),
                        KeyedSubtree(
                          key: PrayerSettingsPage.deliverySectionKey,
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
                                    Expanded(
                                      child: Text(
                                        l10n.todaysSchedule,
                                        style: text.titleLarge,
                                      ),
                                    ),
                                    if (hiddenCount > 0 || _scheduleExpanded)
                                      TextButton(
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
                                      Divider(
                                        height: 28,
                                        color: PrayerCastTokens.rule(context),
                                      ),
                                    PrayerScheduleTile(
                                      prayer: visibleSlots[i],
                                      voiceId: draft.voiceFor(
                                        visibleSlots[i].name,
                                      ),
                                      deliveryMode: draft.deliveryFor(
                                        visibleSlots[i].name,
                                      ),
                                      castVolume: draft.volumeFor(
                                        visibleSlots[i].name,
                                      ),
                                      testing:
                                          _testingPrayer ==
                                          visibleSlots[i].name,
                                      enabled: _testingPrayer == null,
                                      onVoiceChanged: (voiceId) {
                                        _updateDraft(
                                          (d) => d.withVoiceFor(
                                            visibleSlots[i].name,
                                            voiceId,
                                          ),
                                        );
                                      },
                                      onDeliveryChanged: (mode) {
                                        _updateDraft(
                                          (d) => d.withDeliveryFor(
                                            visibleSlots[i].name,
                                            mode,
                                          ),
                                        );
                                      },
                                      onVolumeChanged: (volume) {
                                        _updateDraft(
                                          (d) => d.withVolumeFor(
                                            visibleSlots[i].name,
                                            volume,
                                          ),
                                        );
                                      },
                                      onTest: () => _testDelivery(
                                        visibleSlots[i].name,
                                        draft,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        const SectionRule(),
                        if (PrayerPrefs.prayerKeys.any(
                          (p) =>
                              draft.deliveryFor(p) == PrayerDeliveryMode.cast,
                        )) ...[
                          _CastFallbackCard(
                            enabled: draft.castFallbackToPhone,
                            onChanged: (enabled) {
                              _updateDraft(
                                (d) => d.copyWith(castFallbackToPhone: enabled),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        KeyedSubtree(
                          key: PrayerSettingsPage.remindersSectionKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PrePrayerAlertCard(
                                minutes: draft.prePrayerAlertMinutes,
                                sound: draft.prePrayerAlertSound,
                                onChanged: (minutes) {
                                  _updateDraft(
                                    (d) => d.copyWith(
                                      prePrayerAlertMinutes: minutes,
                                    ),
                                  );
                                },
                                onSoundChanged: (sound) {
                                  _updateDraft(
                                    (d) =>
                                        d.copyWith(prePrayerAlertSound: sound),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              _IqamahReminderCard(
                                draft: draft,
                                onMinutesChanged: (prayer, minutes) {
                                  _updateDraft(
                                    (d) =>
                                        d.withIqamahMinutesFor(prayer, minutes),
                                  );
                                },
                                onSoundChanged: (sound) {
                                  _updateDraft(
                                    (d) => d.copyWith(iqamahSound: sound),
                                  );
                                },
                              ),
                            ],
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
                    label: context.l10n.save,
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
    );
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

  Future<void> _persistDraft({required bool popAfter}) async {
    final prefs = _draft;
    if (prefs == null) return;
    final l10n = context.l10n;
    final hasPlace = prefs.displayLocation.trim().isNotEmpty;
    if (!prefs.hasCoordinates &&
        (prefs.city.isEmpty || prefs.country.isEmpty || !hasPlace)) {
      if (popAfter) {
        _setPageStatus(l10n.needLocationOrCity, error: true);
      }
      return;
    }
    final previous = _lastSaved;
    setState(() => _saving = true);
    try {
      final toWrite = prefs.copyWith(configured: true, defaultsMigrated: true);
      await ref.read(prayerPrefsStoreProvider).write(toWrite);
      _lastSaved = toWrite;
      _draft = toWrite;
      ref.read(adhanNextPrayerProvider).invalidateCache();
      // Invalidate only when leaving — mid-page invalidates flash a loading
      // state and make Switch / SegmentedButton taps feel broken.
      if (popAfter) {
        ref.invalidate(prayerPrefsProvider);
        ref.invalidate(nextPrayerSnapshotProvider);
      }
      final shouldReschedule =
          previous == null || _affectsSchedule(previous, toWrite);
      if (shouldReschedule) {
        await widget.coordinator?.retryScheduleAfterPermissionGranted();
        await widget.coordinator?.refreshPrePrayerAlert();
      }
      widget.onSaved?.call();
      if (!mounted) return;
      if (popAfter) {
        Navigator.of(context).maybePop(toWrite);
      }
    } catch (e) {
      if (!mounted) return;
      _setPageStatus(l10n.saveFailed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(PrayerPrefs prefs) async {
    _saveDebounce?.cancel();
    _draft = prefs;
    await _persistDraft(popAfter: true);
  }

  void _setPageStatus(String message, {required bool error}) {
    setState(() {
      _pageStatus = message;
      _pageStatusIsError = error;
    });
  }

  void _scheduleFocusScroll() {
    if (_didScrollToFocus ||
        _focusScrollPending ||
        widget.focus == PrayerSettingsFocus.none) {
      return;
    }
    _focusScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScrollPending = false;
      if (!mounted || _didScrollToFocus) return;
      if (_revealFocusTarget()) return;
      _focusScrollAttempts++;
      if (_focusScrollAttempts < 24) _scheduleFocusScroll();
    });
  }

  /// Scrolls once the focus section is mounted. Returns false so the caller
  /// can retry after another layout if the lazy list has not built it yet.
  bool _revealFocusTarget() {
    if (!mounted || widget.focus == PrayerSettingsFocus.none) return true;
    final key = widget.focus == PrayerSettingsFocus.delivery
        ? PrayerSettingsPage.deliverySectionKey
        : PrayerSettingsPage.remindersSectionKey;
    final target = _findKeyedElement(context as Element, key);
    final renderObject = target?.renderObject;
    if (target != null && renderObject != null && renderObject.attached) {
      _didScrollToFocus = true;
      Scrollable.ensureVisible(
        target,
        alignment: 0.08,
        duration: Duration.zero,
      );
      return true;
    }
    if (!_focusScroll.hasClients) return false;
    final position = _focusScroll.position;
    if (!position.hasContentDimensions) return false;
    final step = position.pixels + position.viewportDimension;
    final next = step < position.maxScrollExtent
        ? step
        : position.maxScrollExtent;
    if (next > position.pixels + 1) position.jumpTo(next);
    return false;
  }

  Element? _findKeyedElement(Element root, Key key) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  static InputDecoration _fieldDecoration(BuildContext context, String? label) {
    return PrayerCastTheme.darkField(context, label);
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

class _CastFallbackCard extends StatelessWidget {
  const _CastFallbackCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final text = Theme.of(context).textTheme;
    return Material(
      color: PrayerCastTokens.slab(context),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: SwitchListTile(
          key: ValueKey('cast-fallback-switch-$enabled'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            isId
                ? 'Jika speaker tidak tersedia'
                : 'If the speaker is unavailable',
            style: text.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isId
                  ? 'Hanya bila speaker rumah sudah disimpan. Putar Adhan di ponsel jika Cast gagal (atau nada singkat jika lokasi rumah belum yakin).'
                  : 'Only when a home speaker is saved. Play Adhan on this phone if Cast fails (or a short chime if home presence is uncertain).',
              style: text.bodySmall?.copyWith(
                color: PrayerCastTokens.glyphMuted(context),
              ),
            ),
          ),
          value: enabled,
          onChanged: onChanged,
        ),
      ),
    );
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

  static int _normalizedMinutes(int raw) => raw == 10 || raw == 15 ? raw : 0;

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final text = Theme.of(context).textTheme;
    final selectedMinutes = _normalizedMinutes(minutes);
    return Material(
      color: PrayerCastTokens.slab(context),
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
            DropdownButtonFormField<int>(
              key: ValueKey('pre-prayer-minutes-$selectedMinutes'),
              initialValue: selectedMinutes,
              isExpanded: true,
              style: PrayerCastTokens.fieldValue(context),
              dropdownColor: PrayerCastTokens.slab(context),
              items: [
                for (final m in const [0, 10, 15])
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 0
                          ? (isId ? 'Mati' : 'Off')
                          : (isId ? '$m mnt' : '$m min'),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onChanged(value);
              },
              decoration:
                  _PrayerSettingsPageState._fieldDecoration(
                    context,
                    null,
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
            ),
            if (selectedMinutes > 0) ...[
              const SizedBox(height: 12),
              Text(
                isId ? 'Suara pengingat' : 'Reminder sound',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrePrayerAlertSound>(
                key: ValueKey('pre-prayer-sound-${sound.name}'),
                initialValue: sound,
                isExpanded: true,
                style: PrayerCastTokens.fieldValue(context),
                dropdownColor: PrayerCastTokens.slab(context),
                items: [
                  DropdownMenuItem(
                    value: PrePrayerAlertSound.shortBeep,
                    child: Text(isId ? 'Bip pendek' : 'Short beep'),
                  ),
                  DropdownMenuItem(
                    value: PrePrayerAlertSound.longBeep,
                    child: Text(isId ? 'Bip panjang' : 'Long beep'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onSoundChanged(value);
                },
                decoration:
                    _PrayerSettingsPageState._fieldDecoration(
                      context,
                      null,
                    ).copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IqamahReminderCard extends StatelessWidget {
  const _IqamahReminderCard({
    required this.draft,
    required this.onMinutesChanged,
    required this.onSoundChanged,
  });

  final PrayerPrefs draft;
  final void Function(String prayer, int minutes) onMinutesChanged;
  final ValueChanged<IqamahSound> onSoundChanged;

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final text = Theme.of(context).textTheme;
    final anyOn = _prayers.any((p) => draft.iqamahMinutesFor(p) > 0);
    return Material(
      color: PrayerCastTokens.slab(context),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId ? 'Pengingat iqamah' : 'Iqamah reminder',
              style: text.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isId
                  ? 'Notifikasi di ponsel setelah adzan — berdiri untuk sholat. Tidak diputar di speaker.'
                  : 'A phone notification after adhan — stand for prayer. Never plays on the speaker.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final prayer in _prayers) ...[
              if (prayer != _prayers.first) const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      _prayerLabel(prayer, isId: isId),
                      style: text.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(
                        'iqamah-$prayer-${draft.iqamahMinutesFor(prayer)}',
                      ),
                      initialValue: draft.iqamahMinutesFor(prayer),
                      isExpanded: true,
                      style: PrayerCastTokens.fieldValue(context),
                      dropdownColor: PrayerCastTokens.slab(context),
                      items: [
                        for (final m in const [0, 5, 10, 15, 20])
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              m == 0
                                  ? (isId ? 'Mati' : 'Off')
                                  : (isId ? '$m mnt' : '$m min'),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        onMinutesChanged(prayer, value);
                      },
                      decoration:
                          _PrayerSettingsPageState._fieldDecoration(
                            context,
                            null,
                          ).copyWith(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (anyOn) ...[
              const SizedBox(height: 12),
              Text(
                isId ? 'Suara iqamah' : 'Iqamah sound',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<IqamahSound>(
                key: ValueKey('iqamah-sound-${draft.iqamahSound.name}'),
                initialValue: draft.iqamahSound,
                isExpanded: true,
                style: PrayerCastTokens.fieldValue(context),
                dropdownColor: PrayerCastTokens.slab(context),
                items: [
                  DropdownMenuItem(
                    value: IqamahSound.silent,
                    child: Text(isId ? 'Diam' : 'Silent'),
                  ),
                  DropdownMenuItem(
                    value: IqamahSound.chime,
                    child: Text(isId ? 'Nada' : 'Chime'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onSoundChanged(value);
                },
                decoration:
                    _PrayerSettingsPageState._fieldDecoration(
                      context,
                      null,
                    ).copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _prayerLabel(String key, {required bool isId}) {
    if (isId) {
      return switch (key) {
        'fajr' => 'Subuh',
        'dhuhr' => 'Dzuhur',
        'asr' => 'Asar',
        'maghrib' => 'Maghrib',
        'isha' => 'Isya',
        _ => key,
      };
    }
    return switch (key) {
      'fajr' => 'Fajr',
      'dhuhr' => 'Dhuhr',
      'asr' => 'Asr',
      'maghrib' => 'Maghrib',
      'isha' => 'Isha',
      _ => key,
    };
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
  const _StickySaveBar({
    required this.saving,
    required this.onSave,
    required this.label,
  });

  final bool saving;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PrayerCastTokens.surface(context),
        border: Border(
          top: BorderSide(color: PrayerCastTokens.rule(context)),
        ),
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
            child: Text(saving ? context.l10n.saving : label),
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
    required this.castVolume,
    required this.testing,
    required this.enabled,
    required this.onVoiceChanged,
    required this.onDeliveryChanged,
    required this.onVolumeChanged,
    required this.onTest,
  });

  final NextPrayer prayer;
  final String voiceId;
  final PrayerDeliveryMode deliveryMode;

  /// Null = leave speaker volume untouched.
  final double? castVolume;
  final bool testing;
  final bool enabled;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<PrayerDeliveryMode> onDeliveryChanged;
  final ValueChanged<double?> onVolumeChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final t = prayer.scheduledAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final isFajr = prayer.name == 'fajr';
    final resolvedDelivery = deliveryMode == PrayerDeliveryMode.takbir
        ? PrayerDeliveryMode.beep
        : deliveryMode;
    final showVoice = resolvedDelivery.usesVoice;
    final voices = AdzanVoices.forPrayer(prayer.name);
    final resolvedVoiceId = voices.any((v) => v.id == voiceId)
        ? voiceId
        : AdzanVoices.resolve(voiceId, prayerName: prayer.name);

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
                key: ValueKey(
                  'delivery-${prayer.name}-${resolvedDelivery.name}',
                ),
                initialValue: resolvedDelivery,
                isExpanded: true,
                style: PrayerCastTokens.fieldValue(context),
                items: [
                  for (final mode in PrayerDeliveryMode.choices)
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
                        if (mode != null) onDeliveryChanged(mode);
                      }
                    : null,
                decoration: _PrayerSettingsPageState._fieldDecoration(
                  context,
                  null,
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
                key: ValueKey('voice-${prayer.name}-$resolvedVoiceId'),
                initialValue: resolvedVoiceId,
                isExpanded: true,
                style: PrayerCastTokens.fieldValue(context),
                items: [
                  for (final voice in voices)
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
                        if (id != null) onVoiceChanged(id);
                      }
                    : null,
                decoration: _PrayerSettingsPageState._fieldDecoration(
                  context,
                  null,
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
        if (deliveryMode == PrayerDeliveryMode.cast) ...[
          const SizedBox(height: 10),
          _CastVolumeControl(
            prayerName: prayer.name,
            volume: castVolume,
            enabled: enabled,
            onChanged: onVolumeChanged,
          ),
        ],
      ],
    );
  }
}

class _CastVolumeControl extends StatelessWidget {
  const _CastVolumeControl({
    required this.prayerName,
    required this.volume,
    required this.enabled,
    required this.onChanged,
  });

  final String prayerName;
  final double? volume;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final text = Theme.of(context).textTheme;
    final useSpeaker = volume == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: enabled
              ? () {
                  if (useSpeaker) {
                    // First opt-in: mid slider so the control is visible —
                    // not a migration default (existing installs stay null).
                    onChanged(0.5);
                  } else {
                    onChanged(null);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  useSpeaker
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: useSpeaker
                      ? PrayerCastColors.dawn
                      : PrayerCastTokens.glyphMuted(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isId
                        ? 'Pakai volume speaker saat ini'
                        : "Use speaker's current volume",
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!useSpeaker) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: ValueKey('volume-$prayerName'),
                  value: (volume ?? 0.5).clamp(0.0, 1.0),
                  onChanged: enabled ? onChanged : null,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${(((volume ?? 0.5) * 100).round())}%',
                  textAlign: TextAlign.end,
                  style: text.bodySmall?.copyWith(
                    color: PrayerCastTokens.glyphMuted(context),
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
