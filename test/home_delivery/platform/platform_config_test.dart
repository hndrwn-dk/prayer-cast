import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec §5.5 platform configuration checks (manifest / Info.plist).
void main() {
  test(
    'AndroidManifest declares SCHEDULE_EXACT_ALARM but not USE_EXACT_ALARM',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
      // Comment may mention the forbidden permission; the uses-permission must not.
      expect(
        RegExp(
          r'android:name="android\.permission\.USE_EXACT_ALARM"',
        ).hasMatch(manifest),
        isFalse,
      );
      expect(manifest, contains('.AdzanAlarmReceiver'));
      expect(manifest, contains('.AdzanForegroundService'));
      expect(manifest, contains('.BootReceiver'));
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
      expect(manifest, contains('com.coloros.safecenter'));
      expect(manifest, contains('com.oplus.safecenter'));
      expect(manifest, contains('com.miui.securitycenter'));
      expect(manifest, contains('ACCESS_COARSE_LOCATION'));
      expect(manifest, contains('ACCESS_FINE_LOCATION'));
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(manifest, contains('Not used for speaker scan'));
      expect(manifest, contains('NEARBY_WIFI_DEVICES'));
      expect(manifest, contains('neverForLocation'));

      expect(RegExp(r'tools:node="remove"').hasMatch(manifest), isFalse);
    },
  );

  test(
    'AdzanForegroundService is connectedDevice; Cast SDK stays mediaPlayback',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE'),
      );
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
      );
      expect(
        RegExp(
          r'android:name="android\.permission\.FOREGROUND_SERVICE_SPECIAL_USE"',
        ).hasMatch(manifest),
        isFalse,
      );
      expect(
        manifest,
        contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'),
      );
      expect(manifest, contains('android.permission.USE_FULL_SCREEN_INTENT'));

      final adzan = _serviceBlock(manifest, '.AdzanForegroundService');
      expect(
        adzan,
        contains('android:foregroundServiceType="connectedDevice"'),
      );
      expect(adzan, isNot(contains('mediaPlayback')));
      expect(adzan, isNot(contains('specialUse')));
      expect(
        adzan,
        isNot(contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE')),
      );

      final receiver = _receiverBlock(manifest, '.AdzanAlarmReceiver');
      expect(receiver, contains('android:exported="false"'));

      final cast = _serviceBlock(
        manifest,
        'com.google.android.gms.cast.framework.media.MediaNotificationService',
      );
      expect(cast, contains('android:foregroundServiceType="mediaPlayback"'));
      expect(cast, isNot(contains('specialUse')));
      expect(cast, isNot(contains('connectedDevice')));

      final serviceKt = File(
        'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/'
        'AdzanForegroundService.kt',
      ).readAsStringSync();
      expect(serviceKt, contains('FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE'));
      expect(serviceKt, isNot(contains('FOREGROUND_SERVICE_TYPE_SPECIAL_USE')));
      expect(
        serviceKt,
        isNot(contains('FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK')),
      );
      expect(serviceKt, contains('PrayerCastFlutter.ensureStarted'));
      expect(serviceKt, contains('START_REDELIVER_INTENT'));
      expect(serviceKt, isNot(contains('MediaPlayer')));
      expect(serviceKt, isNot(contains('AudioTrack')));
      expect(serviceKt, isNot(contains('MediaSession')));
    },
  );

  test('Android themes omit deprecated Android 15 edge-to-edge window attrs', () {
    for (final relative in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final xml = File(relative).readAsStringSync();
      expect(
        xml,
        isNot(contains('name="android:statusBarColor"')),
      );
      expect(
        xml,
        isNot(contains('name="android:navigationBarColor"')),
      );
      expect(
        xml,
        isNot(contains('windowLayoutInDisplayCutoutMode')),
      );
    }
    final theme = File(
      'lib/home_delivery/ui/theme/prayer_cast_theme.dart',
    ).readAsStringSync();
    expect(theme, contains('forestSystemUi'));
    expect(theme, isNot(contains('statusBarColor:')));
    expect(theme, isNot(contains('systemNavigationBarColor:')));
    expect(theme, isNot(contains('systemNavigationBarDividerColor:')));
    final activity = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('enableEdgeToEdge()'));
    expect(activity, isNot(contains('Color.TRANSPARENT')));
  });

  test('main paints before bootstrap and recovers hung FGS engine', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('initGoogleCast')));
    expect(main, contains('unawaited(runtime.coordinator.start())'));
    expect(main, contains('markDeliveryReady()'));
    expect(main, contains('_BootSplashApp'));
    expect(
      main.indexOf('runApp(const _BootSplashApp())'),
      lessThan(main.indexOf('openDeliveryDatabase()')),
    );
    final runtime = File(
      'lib/home_delivery/coordinator/home_delivery_runtime.dart',
    ).readAsStringSync();
    expect(runtime, isNot(contains('syncTravelLocation(')));
    expect(runtime, contains('Do not call syncTravelLocation'));
    final flutter = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/'
      'PrayerCastFlutter.kt',
    ).readAsStringSync();
    expect(flutter, contains('warmCastOffThread'));
    expect(flutter, contains('engineForActivity'));
    expect(flutter, contains('discardHungEngine'));
    expect(flutter, contains('markDeliveryReady'));
    final activity = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('engineForActivity()'));
    expect(activity, isNot(contains('return PrayerCastFlutter.cached()')));
    // Play Console: enableEdgeToEdge before setContentView (super.onCreate).
    expect(activity, contains('enableEdgeToEdge('));
    expect(
      activity.indexOf('enableEdgeToEdge('),
      lessThan(activity.indexOf('super.onCreate(savedInstanceState)')),
    );
    final exact = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/'
      'ExactAlarmPlugin.kt',
    ).readAsStringSync();
    expect(exact, contains('acknowledgeAlarmFire'));
    expect(exact, contains('Keep the disk copy until'));
  });

  test('BootReceiver and AlarmHealWorker share healPersistedWake', () {
    final boot = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/BootReceiver.kt',
    ).readAsStringSync();
    final worker = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/AlarmHealWorker.kt',
    ).readAsStringSync();
    final exact = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/ExactAlarmPlugin.kt',
    ).readAsStringSync();
    expect(exact, contains('fun healPersistedWake'));
    expect(exact, contains('armRescheduleRetry(context)'));
    expect(boot, contains('ExactAlarmPlugin.healPersistedWake'));
    expect(worker, contains('ExactAlarmPlugin.healPersistedWake'));
    expect(worker, contains('PeriodicWorkRequestBuilder'));
    expect(worker, contains('does not guarantee'));
    expect(worker, contains('WorkManager enqueue failed'));
  });

  test('release ProGuard keeps WorkManager Room database', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('WorkDatabase_Impl'));
    expect(rules, contains('androidx.work.impl.WorkDatabase'));
    expect(rules, contains('AlarmHealWorker'));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('proguard-rules.pro'));
    expect(gradle, contains('InitializationProvider'));
  });

  test('healPersistedWake uses correct conditional logic for past/missing epoch', () {
    final exact = File(
      'android/app/src/main/kotlin/com/tursinalabs/prayer_cast/ExactAlarmPlugin.kt',
    ).readAsStringSync();

    // Verify healPersistedWake structure
    expect(exact, contains('fun healPersistedWake'));
    expect(exact, contains('rearmFromPrefsIfFuture(context)'));
    expect(exact, contains('return armRescheduleRetry(context)'));

    // Verify rearmFromPrefsIfFuture checks for future epoch
    expect(exact, contains('fun rearmFromPrefsIfFuture'));
    expect(exact, contains('epochMs <= System.currentTimeMillis()'));
    expect(exact, contains('return false'));

    // Verify armRescheduleRetry is the fallback for past/missing epochs
    expect(exact, contains('fun armRescheduleRetry'));
    expect(exact, contains('RESCHEDULE_RETRY_PRAYER'));
    expect(exact, contains('RESCHEDULE_RETRY_DELAY_MS'));

    // Verify the flow: healPersistedWake calls rearmFromPrefsIfFuture first,
    // then falls back to armRescheduleRetry if that returns false
    final healFunction = RegExp(
      r'fun healPersistedWake.*?\{.*?if \(rearmFromPrefsIfFuture.*?return true.*?return armRescheduleRetry',
      dotAll: true,
    );
    expect(
      healFunction.hasMatch(exact),
      isTrue,
      reason:
          'healPersistedWake should call rearmFromPrefsIfFuture first, then armRescheduleRetry as fallback',
    );
  });

  test('AndroidManifest does not enable global cleartext HTTP', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(
      RegExp(r'android:usesCleartextTraffic\s*=\s*"true"').hasMatch(manifest),
      isFalse,
    );

    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    );
    expect(config.existsSync(), isTrue);
    final xml = config.readAsStringSync();
    expect(
      RegExp(
        r'<base-config[^>]*cleartextTrafficPermitted\s*=\s*"false"',
      ).hasMatch(xml),
      isTrue,
    );
    expect(
      RegExp(r'cleartextTrafficPermitted\s*=\s*"true"').hasMatch(xml),
      isFalse,
    );
    expect(xml, isNot(contains('src="user"')));
  });

  test('Info.plist has local network, Bonjour, audio, and location usage', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocalNetworkUsageDescription'));
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(
      plist,
      contains(
        'Digunakan untuk menemukan speaker di rumah Anda agar adzan bisa diputar.',
      ),
    );
    expect(plist, contains('_googlecast._tcp'));
    expect(plist, contains('_adzan._tcp'));
    expect(plist, contains('UIBackgroundModes'));
    expect(plist, contains('<string>audio</string>'));
  });
}

String _serviceBlock(String manifest, String androidName) {
  return _componentBlock(manifest, 'service', androidName);
}

String _receiverBlock(String manifest, String androidName) {
  return _componentBlock(manifest, 'receiver', androidName);
}

String _componentBlock(String manifest, String tag, String androidName) {
  final escaped = RegExp.escape(androidName);
  final pattern = RegExp(
    '<$tag\\b[^>]*android:name="$escaped"[^>]*(?:/>|>.*?</$tag>)',
    dotAll: true,
  );
  final match = pattern.firstMatch(manifest);
  expect(
    match,
    isNotNull,
    reason: 'missing <$tag android:name="$androidName">',
  );
  return match!.group(0)!;
}
