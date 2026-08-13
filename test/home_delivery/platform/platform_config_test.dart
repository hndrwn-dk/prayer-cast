import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec §5.5 platform configuration checks (manifest / Info.plist).
void main() {
  test('AndroidManifest declares SCHEDULE_EXACT_ALARM but not USE_EXACT_ALARM',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('android.permission.SCHEDULE_EXACT_ALARM'),
    );
    // Comment may mention the forbidden permission; the uses-permission must not.
    expect(
      RegExp(r'android:name="android\.permission\.USE_EXACT_ALARM"')
          .hasMatch(manifest),
      isFalse,
    );
    expect(manifest, contains('foregroundServiceType="mediaPlayback"'));
    expect(manifest, contains('.AdzanAlarmReceiver'));
    expect(manifest, contains('.AdzanForegroundService'));
    expect(manifest, contains('.BootReceiver'));
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
  });

  test('Info.plist has local network, Bonjour, and audio background mode', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocalNetworkUsageDescription'));
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
