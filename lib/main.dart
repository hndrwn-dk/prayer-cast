import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/common/console_logger.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_delivery_runtime.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/home_delivery/coordinator/prayer_delivery_coordinator.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database_open.dart';
import 'package:prayer_cast/home_delivery/platform/exact_alarm.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_page.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/atmosphere_background.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/premium_mark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openDeliveryDatabase();
  final container = ProviderContainer(
    overrides: [
      deliveryDatabaseProvider.overrideWithValue(db),
    ],
  );

  const logger = ConsoleLogger();
  // TODO(before-release): replace with the real prayer-time calc engine —
  // placeholder only, spec §1 puts calculation out of this repo's scope.
  final nextPrayer = StaticNextPrayerProvider();
  final runtime = await HomeDeliveryRuntime.bootstrap(
    database: db,
    nextPrayer: nextPrayer,
    logger: logger,
    onPermissionChanged: (granted) {
      container.read(exactAlarmPermissionGrantedProvider.notifier).state =
          granted;
    },
  );
  // Listen to onFired before first frame so buffered native pendingFire is kept.
  await runtime.coordinator.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PrayerCastApp(
        exactAlarm: runtime.exactAlarm,
        coordinator: runtime.coordinator,
      ),
    ),
  );
}

/// App shell. Full prayer-time UI is out of scope; home_delivery exposes the
/// local delivery log (§6.3) as the primary surface for this layer.
class PrayerCastApp extends StatelessWidget {
  const PrayerCastApp({
    super.key,
    this.exactAlarm,
    this.coordinator,
  });

  final ExactAlarmPlatform? exactAlarm;
  final PrayerDeliveryCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Cast',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id'),
      supportedLocales: const [
        Locale('id'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have just granted SCHEDULE_EXACT_ALARM in system settings.
      unawaited(_retrySchedule());
    }
  }

  Future<void> _retrySchedule() async {
    await widget.coordinator?.retryScheduleAfterPermissionGranted();
  }

  @override
  Widget build(BuildContext context) {
    final canSchedule = ref.watch(exactAlarmPermissionGrantedProvider);

    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tall = constraints.maxHeight >= 640;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: Row(
                          children: [
                            const BreathPulse(child: PremiumMark(size: 56)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Prayer Cast',
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!canSchedule) ...[
                        const SizedBox(height: 16),
                        _ExactAlarmPermissionBanner(
                          onRequest: () async {
                            await widget.exactAlarm
                                ?.requestExactAlarmPermission();
                            // Settings intent returns immediately; also retry
                            // on next resume via [didChangeAppLifecycleState].
                            await _retrySchedule();
                          },
                        ),
                      ],
                      SizedBox(height: tall ? 72 : 36),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: Text(
                          'Adzan di rumah,\ntepat sekali.',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(height: 1.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 220),
                        child: Text(
                          'Diputar ke speaker rumah hanya saat Anda benar-benar di rumah — tanpa akun, tanpa GPS.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontSize: 19, height: 1.4),
                        ),
                      ),
                      SizedBox(height: tall ? 96 : 40),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: _PrimaryAction(
                          icon: PremiumIcons.clock(
                            size: 26,
                            color: PrayerCastColors.surfaceRaised,
                          ),
                          label: 'Riwayat pengiriman',
                          subtitle: 'Lihat 30 percobaan terakhir',
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder<void>(
                                pageBuilder: (_, animation, __) =>
                                    const DeliveryLogPage(),
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
                                transitionDuration:
                                    const Duration(milliseconds: 380),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          'Data hanya tersimpan di ponsel Anda.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: PrayerCastColors.quiet),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExactAlarmPermissionBanner extends StatelessWidget {
  const _ExactAlarmPermissionBanner({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrayerCastColors.dawnSoft,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Izin alarm tepat waktu diperlukan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Tanpa izin ini, adzan tidak bisa dijadwalkan saat ponsel tidur.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: PrayerCastTheme.minTap,
              child: FilledButton(
                onPressed: onRequest,
                child: const Text('Buka pengaturan alarm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large, full-width interactive control — easy for older fingers, clear for everyone.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: PrayerCastColors.canopy,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PrayerCastColors.surfaceRaised.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: PrayerCastColors.surfaceRaised,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: PrayerCastColors.mist,
                              ),
                        ),
                      ],
                    ),
                  ),
                  PremiumIcons.caretRight(
                    size: 24,
                    color: PrayerCastColors.mist,
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

/// Test helper: run the shell with an injected in-memory database.
class PrayerCastAppForTest extends StatelessWidget {
  const PrayerCastAppForTest({super.key, required this.database});

  final DeliveryDatabase database;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        deliveryDatabaseProvider.overrideWithValue(database),
      ],
      child: const PrayerCastApp(),
    );
  }
}
