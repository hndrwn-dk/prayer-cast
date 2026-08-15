import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/home_onboarding.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';
import 'package:prayer_cast/home_delivery/platform/nearby_wifi_scan_permission.dart';
import 'package:prayer_cast/home_delivery/presence/fingerprint_store.dart';
import 'package:prayer_cast/home_delivery/presence/lan_fingerprint.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/speaker_setup_page.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/home_delivery/ui/widgets/speaker_search_pulse.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

import '../delivery/cast_client_test.dart';
import '../presence/fake_mdns_browser.dart';

CastReceiver _speaker({
  String id = 'nest-1',
  String name = 'Nest Mini Kitchen',
}) {
  return CastReceiver(
    deviceId: id,
    friendlyName: name,
    host: InternetAddress('192.168.1.40'),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        savedHomeSpeakerProvider.overrideWith((ref) async => null),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: PrayerCastTheme.light(),
        home: const SpeakerSetupPage(),
      ),
    ),
  );
  await tester.pump();
}

HomeOnboarding _onboarding({
  required FakeCastPlatform cast,
  MemoryFingerprintStore? store,
}) {
  final fingerprint = store ?? MemoryFingerprintStore();
  return HomeOnboarding(
    castPlatform: cast,
    store: fingerprint,
    lanFingerprint: LanFingerprint(
      browser: FakeMdnsBrowser(const []),
      store: fingerprint,
    ),
  );
}

void main() {
  test('epoch 0 with no cache discovers and writes cache', () async {
    final cast = FakeCastPlatform(devices: [_speaker()]);
    final store = MemoryFingerprintStore();
    final onboarding = _onboarding(cast: cast, store: store);
    final container = ProviderContainer(
      overrides: [homeOnboardingProvider.overrideWith((ref) => onboarding)],
    );
    addTearDown(container.dispose);

    final result = await container.read(speakerDiscoveryProvider.future);
    expect(cast.discoverCalls, 1);
    expect(result.devices.single.deviceId, 'nest-1');
    final cached = await onboarding.readCachedSpeakerScan();
    expect(cached, isNotNull);
    expect(cached!.devices.single.deviceId, 'nest-1');
    expect(cached.devices.single.host.address, '192.168.1.40');
  });

  testWidgets('loading with no previous value shows scanning state', (
    tester,
  ) async {
    final completer = Completer<SpeakerScanResult>();

    await _pumpPage(
      tester,
      overrides: [
        speakerDiscoveryProvider.overrideWith((ref) => completer.future),
      ],
    );

    expect(
      find.byKey(const ValueKey('speaker_scanning_state')),
      findsOneWidget,
    );
    expect(find.byType(SpeakerSearchPulse), findsOneWidget);
    expect(find.text('Searching for speakers…'), findsOneWidget);
    expect(find.text('DEVICE'), findsOneWidget);
    expect(find.text('Home speaker'), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_empty_state')), findsNothing);
    expect(find.byKey(const ValueKey('speaker_error_state')), findsNothing);

    completer.complete(const SpeakerScanResult(devices: []));
    await tester.pump();
  });

  testWidgets('refreshing keeps previous speaker list visible', (tester) async {
    var calls = 0;
    final secondScan = Completer<SpeakerScanResult>();
    final firstSpeaker = _speaker();

    await _pumpPage(
      tester,
      overrides: [
        speakerDiscoveryProvider.overrideWith((ref) async {
          ref.watch(speakerScanEpochProvider);
          calls += 1;
          if (calls == 1) {
            return SpeakerScanResult(devices: [firstSpeaker]);
          }
          return secondScan.future;
        }),
      ],
    );

    // Resolve first scan.
    await tester.pump();
    expect(find.text('Nest Mini Kitchen'), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_scanning_state')), findsNothing);

    // Rescan via header refresh — list must stay.
    await tester.tap(find.byTooltip('Scan again'));
    await tester.pump();

    expect(find.text('Nest Mini Kitchen'), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_scanning_state')), findsNothing);

    secondScan.complete(SpeakerScanResult(devices: [firstSpeaker]));
    await tester.pump();
  });

  testWidgets(
    'second mount reuses cached discovery without scanning-only state',
    (tester) async {
      var calls = 0;
      final speaker = _speaker();
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedHomeSpeakerProvider.overrideWith((ref) async => null),
            speakerDiscoveryProvider.overrideWith((ref) async {
              calls += 1;
              return SpeakerScanResult(devices: [speaker]);
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: PrayerCastTheme.light(),
            navigatorKey: navKey,
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    navKey.currentState!.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SpeakerSetupPage(),
                      ),
                    );
                  },
                  child: const Text('open setup'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // First visit — discovery runs once.
      await tester.tap(find.text('open setup'));
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Nest Mini Kitchen'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('speaker_scanning_state')),
        findsNothing,
      );

      // Leave Speaker Setup (same ProviderScope / app session).
      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump();
      expect(find.text('open setup'), findsOneWidget);
      expect(find.text('Nest Mini Kitchen'), findsNothing);

      // Re-open — cached list, no scanning-only state, no second scan.
      await tester.tap(find.text('open setup'));
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Nest Mini Kitchen'), findsOneWidget);
      expect(find.byKey(const ValueKey('speaker_list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('speaker_scanning_state')),
        findsNothing,
      );
      expect(find.byType(SpeakerSearchPulse), findsNothing);
    },
  );

  testWidgets('empty success shows empty state not scanning', (tester) async {
    await _pumpPage(
      tester,
      overrides: [
        speakerDiscoveryProvider.overrideWith(
          (ref) async => const SpeakerScanResult(devices: []),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('speaker_empty_state')), findsOneWidget);
    expect(find.text('No speakers found'), findsOneWidget);
    expect(
      find.text(
        'Make sure your phone and speaker are on the same Wi‑Fi network',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('speaker_scanning_state')), findsNothing);
    expect(find.byType(SpeakerSearchPulse), findsNothing);
    expect(find.byKey(const ValueKey('speaker_scan_retry')), findsOneWidget);
  });

  testWidgets('thrown error shows error state with retry', (tester) async {
    await _pumpPage(
      tester,
      overrides: [
        speakerDiscoveryProvider.overrideWith(
          (ref) async => throw Exception('discovery boom'),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('speaker_error_state')), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_scan_retry')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_scanning_state')), findsNothing);
    expect(find.byKey(const ValueKey('speaker_empty_state')), findsNothing);
  });

  testWidgets('shows group delay hint and marks group rows', (tester) async {
    await _pumpPage(
      tester,
      overrides: [
        speakerDiscoveryProvider.overrideWith(
          (ref) async => SpeakerScanResult(
            devices: [
              _speaker(),
              _speaker(id: 'group-1', name: 'Home group speaker'),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('speaker_group_delay_hint')), findsOneWidget);
    expect(
      find.textContaining('Cast groups (Xiaomi, mixed brands'),
      findsOneWidget,
    );
    expect(find.text('May start late'), findsOneWidget);
    expect(find.text('reachable now'), findsOneWidget);
  });

  testWidgets(
    'disk cache shows list immediately without scanning or discover',
    (tester) async {
      final cached = _speaker();
      final cast = FakeCastPlatform(
        devices: [_speaker(id: 'live-1', name: 'Live Speaker')],
      );
      final onboarding = _onboarding(cast: cast);
      await onboarding.writeCachedSpeakerScan(
        SpeakerScanResult(devices: [cached]),
      );

      await _pumpPage(
        tester,
        overrides: [homeOnboardingProvider.overrideWith((ref) => onboarding)],
      );
      await tester.pump();

      expect(find.text('Nest Mini Kitchen'), findsOneWidget);
      expect(find.byKey(const ValueKey('speaker_list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('speaker_scanning_state')),
        findsNothing,
      );
      expect(find.byType(SpeakerSearchPulse), findsNothing);
      expect(find.text('Live Speaker'), findsNothing);
      expect(cast.discoverCalls, 0);
    },
  );

  testWidgets('refresh increments epoch and calls discover', (tester) async {
    final cached = _speaker();
    final cast = FakeCastPlatform(
      devices: [_speaker(id: 'live-1', name: 'Live Speaker')],
    );
    final onboarding = _onboarding(cast: cast);
    await onboarding.writeCachedSpeakerScan(
      SpeakerScanResult(devices: [cached]),
    );

    await _pumpPage(
      tester,
      overrides: [homeOnboardingProvider.overrideWith((ref) => onboarding)],
    );
    await tester.pump();
    expect(cast.discoverCalls, 0);
    expect(find.text('Nest Mini Kitchen'), findsOneWidget);

    await tester.tap(find.byTooltip('Scan again'));
    await tester.pump();
    await tester.pump();

    expect(cast.discoverCalls, 1);
    expect(find.text('Live Speaker'), findsOneWidget);
    expect(find.text('Nest Mini Kitchen'), findsNothing);
  });

  testWidgets(
    'selecting a cached speaker saves CastReceiver without discover',
    (tester) async {
      final cached = _speaker();
      final store = MemoryFingerprintStore();
      final cast = FakeCastPlatform(devices: []);
      final onboarding = _onboarding(cast: cast, store: store);
      await onboarding.writeCachedSpeakerScan(
        SpeakerScanResult(devices: [cached]),
      );

      await _pumpPage(
        tester,
        overrides: [homeOnboardingProvider.overrideWith((ref) => onboarding)],
      );
      await tester.pump();

      await tester.tap(find.text('Nest Mini Kitchen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await store.readHomeCastId(), 'nest-1');
      expect(await store.readHomeCastFriendlyName(), 'Nest Mini Kitchen');
      expect(cast.discoverCalls, 0);
    },
  );

  testWidgets('refresh error keeps previous cached list', (tester) async {
    final cached = _speaker();
    final cast = FakeCastPlatform(devices: [cached]);
    final onboarding = _onboarding(cast: cast);
    await onboarding.writeCachedSpeakerScan(
      SpeakerScanResult(devices: [cached]),
    );

    await _pumpPage(
      tester,
      overrides: [homeOnboardingProvider.overrideWith((ref) => onboarding)],
    );
    await tester.pump();
    expect(find.text('Nest Mini Kitchen'), findsOneWidget);

    cast.discoverError = Exception('wifi down');
    await tester.tap(find.byTooltip('Scan again'));
    await tester.pump();
    await tester.pump();

    expect(cast.discoverCalls, 1);
    expect(find.text('Nest Mini Kitchen'), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('speaker_error_state')), findsNothing);
  });

  testWidgets(
    'API 33 nearby-wifi denied shows error and settings, no discover',
    (tester) async {
      var requested = false;
      final cast = FakeCastPlatform(devices: [_speaker()]);
      final onboarding = _onboarding(cast: cast);

      await _pumpPage(
        tester,
        overrides: [
          homeOnboardingProvider.overrideWith((ref) => onboarding),
          nearbyWifiScanPermissionProvider.overrideWithValue(
            NearbyWifiScanPermission(
              isAndroid: true,
              androidSdkInt: 33,
              ensureAndroidGranted: () async {
                requested = true;
                return false;
              },
            ),
          ),
        ],
      );
      await tester.pump();

      expect(requested, isTrue);
      expect(cast.discoverCalls, 0);
      expect(find.byKey(const ValueKey('speaker_error_state')), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    },
  );

  testWidgets('API 32 scan does not request nearby-wifi or location',
      (tester) async {
    var requested = false;
    final cast = FakeCastPlatform(devices: [_speaker()]);
    final onboarding = _onboarding(cast: cast);

    await _pumpPage(
      tester,
      overrides: [
        homeOnboardingProvider.overrideWith((ref) => onboarding),
        nearbyWifiScanPermissionProvider.overrideWithValue(
          NearbyWifiScanPermission(
            isAndroid: true,
            androidSdkInt: 32,
            ensureAndroidGranted: () async {
              requested = true;
              return false;
            },
          ),
        ),
      ],
    );
    await tester.pump();

    expect(requested, isFalse);
    expect(cast.discoverCalls, 1);
    expect(find.text('Nest Mini Kitchen'), findsOneWidget);
  });
}
