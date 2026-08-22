import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:prayer_cast/home_delivery/common/console_logger.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_audio_loader.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_delivery_runtime.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/coordinator/local_prayer_player.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_init.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database_open.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/platform/launch_prayer.dart';
import 'package:prayer_cast/home_delivery/platform/post_notifications_permission.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/presence/mdns_browser.dart';
import 'package:prayer_cast/home_delivery/presence/presence_service.dart';
import 'package:prayer_cast/home_delivery/presence/presence_state.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/speaker_setup_page.dart';
import 'package:prayer_cast/home_delivery/ui/spiritual_benefits_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/atmosphere_background.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/adhan_countdown.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/editorial_chrome.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/oem_autostart_banner.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/spiritual_benefits_teaser.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/l10n/locale_controller.dart';
import 'package:prayer_cast/prayer_times/adhan_next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/prayer_times/spiritual_benefits.dart';
import 'package:prayer_cast/prayer_times/ui/prayer_settings_page.dart';
import 'package:prayer_cast/support/open_support_url.dart';
import 'package:prayer_cast/support/support_icon_button.dart';

/// Mirrors pubspec.yaml `version:`. Bump both together.
const String kAppVersion = '1.0.8+9';

/// Android 13+ [POST_NOTIFICATIONS]. Default true so widget tests stay clean.
final postNotificationsGrantedProvider = StateProvider<bool>((ref) => true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGoogleCast();

  final db = await openDeliveryDatabase();
  final docs = await getApplicationDocumentsDirectory();
  final prayerPrefsStore = FilePrayerPrefsStore(
    File(p.join(docs.path, 'prayer_prefs.txt')),
  );
  final localeStore = FileLocaleStore(
    File(p.join(docs.path, 'app_locale.txt')),
  );

  const logger = ConsoleLogger();
  final nextPrayer = AdhanNextPrayerProvider(
    store: prayerPrefsStore,
    scheduleCacheFile: File(p.join(docs.path, 'prayer_schedule_cache.json')),
  );
  final onboardingHolder = _OnboardingHolder();
  final castTesterHolder = _CastTesterHolder();
  final localPlayerHolder = _LocalPlayerHolder();
  final presenceHolder = _PresenceHolder();

  final appContainer = ProviderContainer(
    overrides: [
      deliveryDatabaseProvider.overrideWithValue(db),
      prayerPrefsStoreProvider.overrideWithValue(prayerPrefsStore),
      localeStoreProvider.overrideWithValue(localeStore),
      adhanNextPrayerProvider.overrideWithValue(nextPrayer),
      homeOnboardingProvider.overrideWith((ref) {
        final onboarding = onboardingHolder.value;
        if (onboarding == null) {
          throw StateError('HomeOnboarding not ready');
        }
        return onboarding;
      }),
      adzanCastTesterProvider.overrideWith((ref) {
        final tester = castTesterHolder.value;
        if (tester == null) {
          throw StateError('AdzanCastTester not ready');
        }
        return tester;
      }),
      localPrayerPlayerProvider.overrideWith((ref) {
        final player = localPlayerHolder.value;
        if (player == null) {
          throw StateError('LocalPrayerPlayer not ready');
        }
        return player;
      }),
      presenceServiceProvider.overrideWith((ref) => presenceHolder.value),
    ],
  );

  final runtime = await HomeDeliveryRuntime.bootstrap(
    database: db,
    nextPrayer: nextPrayer,
    prayerPrefs: prayerPrefsStore,
    logger: logger,
    onPermissionChanged: (granted) {
      appContainer.read(exactAlarmPermissionGrantedProvider.notifier).state =
          granted;
    },
  );
  onboardingHolder.value = runtime.onboarding;
  castTesterHolder.value = runtime.castTester;
  localPlayerHolder.value = runtime.localPlayer;
  presenceHolder.value = runtime.presence;

  // Listen to onFired before first frame so buffered native pendingFire is kept.
  await runtime.coordinator.start();

  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: PrayerCastApp(
        exactAlarm: runtime.exactAlarm,
        coordinator: runtime.coordinator,
      ),
    ),
  );
}

final class _OnboardingHolder {
  HomeOnboarding? value;
}

final class _CastTesterHolder {
  AdzanCastTester? value;
}

final class _LocalPlayerHolder {
  LocalPrayerPlayer? value;
}

final class _PresenceHolder {
  PresenceService? value;
}

/// App shell with speaker setup, prayer times, and delivery log.
class PrayerCastApp extends ConsumerWidget {
  const PrayerCastApp({
    super.key,
    this.exactAlarm,
    this.coordinator,
  });

  final ExactAlarmPlatform? exactAlarm;
  final PrayerDeliveryCoordinator? coordinator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeOverride = ref.watch(appLocaleProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: localeOverride,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (locale, supported) {
        if (localeOverride != null) return localeOverride;
        if (locale != null) {
          for (final s in supported) {
            if (s.languageCode == locale.languageCode) return s;
          }
        }
        return const Locale('id');
      },
      theme: PrayerCastTheme.light(),
      home: _HomeShell(
        exactAlarm: exactAlarm,
        coordinator: coordinator,
      ),
    );
  }
}

class _HomeShell extends ConsumerStatefulWidget {
  const _HomeShell({this.exactAlarm, this.coordinator});

  final ExactAlarmPlatform? exactAlarm;
  final PrayerDeliveryCoordinator? coordinator;

  @override
  ConsumerState<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<_HomeShell>
    with WidgetsBindingObserver {
  final LaunchPrayer _launchPrayer = LaunchPrayer();
  String? _lastLaunchPrayer;
  DateTime? _lastLaunchAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchPrayer.onPrayer = _openSpiritualBenefitsFromLaunch;
    _launchPrayer.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeLaunchPrayer());
      unawaited(_refreshNotificationPermission());
    });
  }

  @override
  void dispose() {
    _launchPrayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _consumeLaunchPrayer() async {
    final prayer = await _launchPrayer.consume();
    if (prayer == null || !mounted) return;
    _openSpiritualBenefitsFromLaunch(prayer);
  }

  void _openSpiritualBenefitsFromLaunch(String prayer) {
    if (!mounted) return;
    // Dry-run is for the alarm / Cast path. The T−120 shade already
    // shows the teaser; the full card opens only on a user tap.
    if (PrayerDeliveryCoordinator.isDryRunPrayer(prayer)) return;
    final key = PrayerDeliveryCoordinator.canonicalPrayerName(prayer);
    final now = DateTime.now();
    if (isDuplicateLaunchPrayer(
      prayer: key,
      previousPrayer: _lastLaunchPrayer,
      previousAt: _lastLaunchAt,
      now: now,
    )) {
      return;
    }
    _lastLaunchPrayer = key;
    _lastLaunchAt = now;
    _openSpiritualBenefits(prayer);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_retrySchedule());
      unawaited(_refreshNotificationPermission());
      ref.invalidate(homePresenceProvider);
    }
  }

  Future<void> _retrySchedule() async {
    await widget.coordinator?.retryScheduleAfterPermissionGranted();
  }

  Future<void> _refreshNotificationPermission() async {
    try {
      final granted = await const PostNotificationsPermission().isGranted();
      if (!mounted) return;
      ref.read(postNotificationsGrantedProvider.notifier).state = granted;
    } catch (_) {}
  }

  Future<void> _requestNotifications() async {
    final gate = const PostNotificationsPermission();
    var granted = await gate.isGranted();
    if (!granted) {
      granted = await gate.request();
    }
    if (!granted) {
      await gate.openSettings();
      granted = await gate.isGranted();
    }
    if (!mounted) return;
    ref.read(postNotificationsGrantedProvider.notifier).state = granted;
  }

  Future<void> _openSpeakerSetup() async {
    await Navigator.of(context).push(
      _fadeRoute(const SpeakerSetupPage()),
    );
    ref.invalidate(savedHomeSpeakerProvider);
    ref.invalidate(homePresenceProvider);
  }

  Future<void> _openPrayerSettings() async {
    await Navigator.of(context).push(
      _fadeRoute(PrayerSettingsPage(coordinator: widget.coordinator)),
    );
    ref.invalidate(prayerPrefsProvider);
    ref.invalidate(nextPrayerSnapshotProvider);
  }

  void _openSpiritualBenefits(String prayer) {
    final key = PrayerDeliveryCoordinator.canonicalPrayerName(prayer);
    if (!SpiritualBenefits.isSupported(key) || !mounted) return;
    Navigator.of(context).push(
      _fadeRoute(
        SpiritualBenefitsPage(prayer: key),
        settings: RouteSettings(
          name: SpiritualBenefitsPage.routeName,
          arguments: key,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSchedule = ref.watch(exactAlarmPermissionGrantedProvider);
    final notificationsGranted = ref.watch(postNotificationsGrantedProvider);
    final restrictiveOem = ref.watch(restrictiveOemProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    final speaker = ref.watch(savedHomeSpeakerProvider);
    final nextPrayer = ref.watch(nextPrayerSnapshotProvider);
    final prefs = ref.watch(prayerPrefsProvider);
    final presence = ref.watch(homePresenceProvider);
    final localeOverride = ref.watch(appLocaleProvider);
    final activeLang =
        localeOverride?.languageCode ?? Localizations.localeOf(context).languageCode;

    final speakerName = speaker.when(
      data: (s) => s?.displayName,
      loading: () => null,
      error: (_, __) => null,
    );
    final speakerLoading = speaker.isLoading;

    final nextHeroConfigured = nextPrayer.maybeWhen(
      data: (n) => n != null,
      orElse: () => false,
    );
    final nextAt = nextPrayer.maybeWhen(
      data: (n) => n?.scheduledAt,
      orElse: () => null,
    );
    final nextTime = nextAt == null ? null : _fmtTime(nextAt);
    final nextName = nextPrayer.maybeWhen(
      data: (n) => n == null ? null : prayerDisplayName(l10n, n.name),
      orElse: () => null,
    );
    final nextPrayerKey = nextPrayer.maybeWhen(
      data: (n) => n == null
          ? null
          : PrayerDeliveryCoordinator.canonicalPrayerName(n.name),
      orElse: () => null,
    );
    final nextEmptyLabel = nextPrayer.when(
      data: (n) => n == null ? l10n.prayerNotConfigured : null,
      loading: () => l10n.prayerLoading,
      error: (_, __) => l10n.prayerNotConfigured,
    );
    // Hide factory-default city until the user has saved settings.
    final cityLabel = prefs.maybeWhen(
      data: (p) {
        if (!p.configured) return null;
        final city = p.city.trim();
        return city.isEmpty ? null : city;
      },
      orElse: () => null,
    );
    final countryLabel = prefs.maybeWhen(
      data: (p) {
        if (!p.configured) return null;
        final country = p.country.trim();
        return country.isEmpty ? null : country;
      },
      orElse: () => null,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: PrayerCastColors.ink,
      ),
      child: Scaffold(
        backgroundColor: PrayerCastColors.ink,
        body: ColoredBox(
          color: PrayerCastColors.ink,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHero(
                  activeLang: activeLang,
                  canSchedule: canSchedule,
                  notificationsGranted: notificationsGranted,
                  showOemAutostart: restrictiveOem &&
                      (nextHeroConfigured || speakerName != null),
                  nextHeroConfigured: nextHeroConfigured,
                  nextAt: nextAt,
                  nextTime: nextTime,
                  nextName: nextName,
                  nextPrayerKey: nextPrayerKey,
                  nextEmptyLabel: nextEmptyLabel,
                  cityLabel: cityLabel,
                  countryLabel: countryLabel,
                  presenceLabel: _presenceLabel(l10n, presence),
                  speakerName: speakerName,
                  speakerLoading: speakerLoading,
                  onLanguageSelected: (code) {
                    unawaited(
                      ref
                          .read(appLocaleProvider.notifier)
                          .setLocale(Locale(code)),
                    );
                  },
                  onRequestExactAlarm: () async {
                    await widget.exactAlarm
                        ?.requestExactAlarmPermission();
                    await _retrySchedule();
                  },
                  onRequestNotifications: _requestNotifications,
                  onOpenAutostart: () {
                    unawaited(
                      ref.read(oemBatterySettingsProvider).openAutostartSettings(),
                    );
                  },
                  onUnsetPrayerTap:
                      nextHeroConfigured ? null : _openPrayerSettings,
                  onSpiritualBenefitsTap: nextPrayerKey == null
                      ? null
                      : () => _openSpiritualBenefits(nextPrayerKey),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: _SpeakerBand(
                    speakerName: speakerName,
                    speakerLoading: speakerLoading,
                    onTap: _openSpeakerSetup,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: _PrayerTimesSlab(
                    onTap: _openPrayerSettings,
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: PrayerCastColors.ink,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        child: IgnorePointer(
                          child: ColoredBox(color: PrayerCastColors.ink),
                        ),
                      ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: SafeArea(
                          top: false,
                          child: ColophonFootnote(
                            message: l10n.dataOnDeviceOnly,
                            versionLine: 'version: $kAppVersion',
                            privacyTooltip: l10n.privacyPolicy,
                            onPrivacyTap: () => openPrivacyPolicyUrl(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.activeLang,
    required this.canSchedule,
    required this.notificationsGranted,
    required this.nextHeroConfigured,
    this.nextAt,
    required this.nextTime,
    required this.nextName,
    this.nextPrayerKey,
    required this.nextEmptyLabel,
    required this.cityLabel,
    required this.countryLabel,
    required this.presenceLabel,
    required this.speakerName,
    required this.speakerLoading,
    required this.onLanguageSelected,
    required this.onRequestExactAlarm,
    required this.onRequestNotifications,
    required this.showOemAutostart,
    required this.onOpenAutostart,
    this.onUnsetPrayerTap,
    this.onSpiritualBenefitsTap,
  });

  final String activeLang;
  final bool canSchedule;
  final bool notificationsGranted;
  final bool showOemAutostart;
  final VoidCallback onOpenAutostart;
  final bool nextHeroConfigured;
  final DateTime? nextAt;
  final String? nextTime;
  final String? nextName;
  final String? nextPrayerKey;
  final String? nextEmptyLabel;
  final String? cityLabel;
  final String? countryLabel;
  final String presenceLabel;
  final String? speakerName;
  final bool speakerLoading;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onRequestExactAlarm;
  final VoidCallback onRequestNotifications;
  final VoidCallback? onUnsetPrayerTap;
  final VoidCallback? onSpiritualBenefitsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final placeDetail = speakerLoading
        ? l10n.speakerLoading
        : speakerName;

    return ColoredBox(
      color: PrayerCastColors.canopyDeep,
      child: Stack(
        children: [
          const Positioned.fill(child: CrescentField()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: _HomeMasthead(
                      activeLang: activeLang,
                      onLanguageSelected: onLanguageSelected,
                    ),
                  ),
                  if (!canSchedule) ...[
                    const SizedBox(height: 16),
                    _ExactAlarmPermissionBanner(onRequest: onRequestExactAlarm),
                  ],
                  if (!notificationsGranted) ...[
                    const SizedBox(height: 16),
                    _NotificationPermissionBanner(
                      onRequest: onRequestNotifications,
                    ),
                  ],
                  if (showOemAutostart) ...[
                    const SizedBox(height: 16),
                    OemAutostartBanner(onOpen: onOpenAutostart),
                  ],
                  const SizedBox(height: 48),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: _NextAdhanJewel(
                      configured: nextHeroConfigured,
                      scheduledAt: nextAt,
                      time: nextTime,
                      prayerName: nextName,
                      prayerKey: nextPrayerKey,
                      emptyLabel: nextEmptyLabel,
                      onUnsetTap: onUnsetPrayerTap,
                      onSpiritualBenefitsTap: onSpiritualBenefitsTap,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _PlaceAndPresence(
                      city: cityLabel,
                      country: countryLabel,
                      presenceLabel: presenceLabel,
                      placeDetail: placeDetail,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMasthead extends StatelessWidget {
  const _HomeMasthead({
    required this.activeLang,
    required this.onLanguageSelected,
  });

  final String activeLang;
  final ValueChanged<String> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.appTitle,
      header: true,
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRAYER',
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.displayFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3.2,
                    height: 1,
                    color: PrayerCastColors.mist,
                    fontVariations: [FontVariation('wght', 500)],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cast',
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.displayFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    height: 1.05,
                    color: PrayerCastColors.surfaceRaised,
                    fontVariations: [FontVariation('wght', 500)],
                  ),
                ),
                const SizedBox(height: 14),
                const EditorialHairline(),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SupportIconButton(color: PrayerCastColors.mist),
              PopupMenuButton<String>(
                key: const ValueKey('language_menu'),
                tooltip: '${l10n.language} (${activeLang.toUpperCase()})',
                padding: EdgeInsets.zero,
                initialValue: activeLang,
                color: PrayerCastColors.canopyDeep,
                onSelected: onLanguageSelected,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'id',
                    child: Text(
                      l10n.languageIndonesian,
                      style: PrayerCastTheme.forestDropdown,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Text(
                      l10n.languageEnglish,
                      style: PrayerCastTheme.forestDropdown,
                    ),
                  ),
                ],
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.language,
                      size: 22,
                      color: PrayerCastColors.mist,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextAdhanJewel extends StatelessWidget {
  const _NextAdhanJewel({
    required this.configured,
    this.scheduledAt,
    required this.time,
    required this.prayerName,
    this.prayerKey,
    required this.emptyLabel,
    this.onUnsetTap,
    this.onSpiritualBenefitsTap,
  });

  final bool configured;
  final DateTime? scheduledAt;
  final String? time;
  final String? prayerName;
  final String? prayerKey;
  final String? emptyLabel;
  final VoidCallback? onUnsetTap;
  final VoidCallback? onSpiritualBenefitsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialEyebrow(l10n.nextAdhanEyebrow),
        const SizedBox(height: 10),
        if (configured && time != null) ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(time!, style: PrayerCastTheme.heroTime),
          ),
          if (scheduledAt != null) ...[
            const SizedBox(height: 8),
            AdhanCountdownLabel(
              scheduledAt: scheduledAt!,
              prayerName: prayerName,
            ),
          ] else if (prayerName != null) ...[
            const SizedBox(height: 8),
            Text(
              prayerName!,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.displayFont,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
                color: PrayerCastColors.mist,
              ),
            ),
          ],
          if (prayerKey != null && onSpiritualBenefitsTap != null)
            SpiritualBenefitsTeaserLine(
              prayerKey: prayerKey!,
              onTap: onSpiritualBenefitsTap!,
            ),
        ] else
          Text(
            emptyLabel ?? l10n.prayerNotConfigured,
            style: const TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: PrayerCastColors.mist,
            ),
          ),
      ],
    );

    if (onUnsetTap == null) return child;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onUnsetTap, child: child),
    );
  }
}

class _PlaceAndPresence extends StatelessWidget {
  const _PlaceAndPresence({
    required this.city,
    required this.country,
    required this.presenceLabel,
    this.placeDetail,
  });

  final String? city;
  final String? country;
  final String presenceLabel;
  final String? placeDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const placeStyle = TextStyle(
      fontFamily: PrayerCastTheme.bodyFont,
      fontSize: 14,
      letterSpacing: 0.15,
      height: 1.45,
      color: PrayerCastColors.mist,
    );
    const countryStyle = TextStyle(
      fontFamily: PrayerCastTheme.bodyFont,
      fontSize: 14,
      height: 1.45,
      color: PrayerCastColors.mistDeep,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (city != null)
          Text(
            '${l10n.city}: $city',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: placeStyle,
          ),
        if (country != null)
          Text(
            '${l10n.country}: $country',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countryStyle,
          ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const EditorialHairline(vertical: true, height: 28, width: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditorialEyebrow(presenceLabel),
                  if (placeDetail != null && placeDetail!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      placeDetail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: PrayerCastTheme.displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: PrayerCastColors.surfaceRaised,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeakerBand extends StatelessWidget {
  const _SpeakerBand({
    required this.speakerName,
    required this.speakerLoading,
    required this.onTap,
  });

  final String? speakerName;
  final bool speakerLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = speakerLoading
        ? l10n.speakerLoading
        : (speakerName ?? l10n.speakerCardEmpty);
    return ColoredBox(
      color: PrayerCastColors.canopyDeep,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialEyebrow(
              l10n.deviceEyebrow,
              color: PrayerCastColors.dawn,
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: l10n.changeHomeSpeaker,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        IconWell(
                          child: PremiumIcons.speaker(
                            size: 18,
                            color: PrayerCastColors.mist,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.changeHomeSpeaker,
                                style: const TextStyle(
                                  fontFamily: PrayerCastTheme.displayFont,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  height: 1.2,
                                  color: PrayerCastColors.surfaceRaised,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: PrayerCastTheme.bodyFont,
                                  fontSize: 13,
                                  height: 1.35,
                                  color: PrayerCastColors.mistDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PremiumIcons.caretRight(
                          size: 18,
                          color: PrayerCastColors.mist,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimesSlab extends StatelessWidget {
  const _PrayerTimesSlab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.prayerTimes,
      child: Material(
        key: const ValueKey<String>('home_prayer_times_slab'),
        color: PrayerCastColors.ink,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorialEyebrow(
                  l10n.scheduleEyebrow,
                  color: PrayerCastColors.leaf,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.prayerTimes,
                  style: const TextStyle(
                    fontFamily: PrayerCastTheme.displayFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: PrayerCastColors.surfaceRaised,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.prayerTimesHint,
                  style: const TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 13,
                    height: 1.4,
                    color: PrayerCastColors.mistDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _presenceLabel(AppLocalizations l10n, AsyncValue<PresenceState> presence) {
  return presence.when(
    loading: () => l10n.checkingHome,
    error: (_, __) => l10n.checkingHome,
    data: (state) => switch (state) {
      PresenceState.home => l10n.homeDetected,
      PresenceState.away => l10n.notHome,
      PresenceState.unknown => l10n.checkingHome,
    },
  );
}

class _ExactAlarmPermissionBanner extends StatelessWidget {
  const _ExactAlarmPermissionBanner({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: PrayerCastColors.dawnSoft,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exactAlarmTitle,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.exactAlarmBody,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                height: 1.4,
                color: PrayerCastColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                onPressed: onRequest,
                child: Text(l10n.exactAlarmOpenSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPermissionBanner extends StatelessWidget {
  const _NotificationPermissionBanner({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: PrayerCastColors.dawnSoft,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationsBlockedTitle,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.notificationsBlockedBody,
              style: const TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                height: 1.4,
                color: PrayerCastColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                onPressed: onRequest,
                child: Text(l10n.notificationsBlockedAllow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PageRouteBuilder<void> _fadeRoute(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 380),
  );
}

String _fmtTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Test helper: run the shell with an injected in-memory database.
class PrayerCastAppForTest extends StatelessWidget {
  const PrayerCastAppForTest({
    super.key,
    required this.database,
    this.prayerPrefs,
    this.nextPrayer,
  });

  final DeliveryDatabase database;
  final PrayerPrefs? prayerPrefs;
  final NextPrayer? nextPrayer;

  @override
  Widget build(BuildContext context) {
    final store = MemoryFingerprintStore();
    final prefsStore = MemoryPrayerPrefsStore(prayerPrefs);
    return ProviderScope(
      overrides: [
        deliveryDatabaseProvider.overrideWithValue(database),
        prayerPrefsStoreProvider.overrideWithValue(prefsStore),
        adhanNextPrayerProvider.overrideWithValue(
          AdhanNextPrayerProvider(store: prefsStore),
        ),
        if (nextPrayer != null)
          nextPrayerSnapshotProvider.overrideWith((ref) async => nextPrayer),
        homeOnboardingProvider.overrideWithValue(
          HomeOnboarding(
            castPlatform: _NoopCastPlatform(),
            store: store,
            lanFingerprint: LanFingerprint(
              browser: _EmptyMdnsBrowser(),
              store: store,
            ),
          ),
        ),
        adzanCastTesterProvider.overrideWithValue(
          AdzanCastTester(
            castClient: CastClient(platform: _NoopCastPlatform()),
            store: store,
            audioLoader: _EmptyAudioLoader(),
          ),
        ),
        localPrayerPlayerProvider.overrideWithValue(
          const SilentLocalPrayerPlayer(),
        ),
        localeStoreProvider.overrideWithValue(MemoryLocaleStore('id')),
      ],
      child: const PrayerCastApp(),
    );
  }
}

final class _EmptyAudioLoader implements AdzanAudioLoader {
  @override
  Future<AdzanAudioData> load(String voiceId) async => AdzanAudioData(
        bytes: Uint8List(0),
        contentType: 'audio/mpeg',
        extension: 'mp3',
      );
}

final class _NoopCastPlatform implements CastPlatform {
  @override
  Stream<CastPlaybackEvent> get playbackEvents => const Stream.empty();

  @override
  Future<List<CastReceiver>> discover({
    required Duration budget,
    String? matchId,
  }) async =>
      const [];

  @override
  Future<void> connect(CastReceiver receiver) async {}

  @override
  Future<void> warmUp() async {}

  @override
  Future<double> getVolume() async => 0.5;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<CastMediaSnapshot?> currentMedia() async => null;

  @override
  Future<void> loadMedia({
    required String contentId,
    required Uri contentUrl,
    required String contentType,
    String? title,
  }) async {}

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 15),
  }) async {}

  @override
  Future<void> endSession() async {}
}

final class _EmptyMdnsBrowser implements MdnsBrowser {
  @override
  Future<List<DiscoveredService>> browse({
    required List<String> serviceTypes,
    required Duration budget,
    bool Function(List<DiscoveredService> soFar)? shouldStop,
  }) async =>
      const [];
}
