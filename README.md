# Prayer Cast

Tursina Labs — offline-first prayer times. When you are actually home, the
app casts the adzan to your Google Cast / Nest speaker, once across family
phones.

See [ADZAN_HOME_DELIVERY_SPEC.md](./ADZAN_HOME_DELIVERY_SPEC.md) for the
`home_delivery` layer (presence → coordination → cast).

## What it does

- **Prayer times** from Aladhan (city or GPS). Indonesia auto-uses Kemenag
  jadwal via myQuran (city id, not coordinates). Singapore MUIS is method 11.
  Hanafi vs Shafi'i changes **Asr only** on Aladhan (Hanafi is later).
- **Home speaker** — scan the LAN, pick a Cast target (groups from Google
  Home). The last scan is cached on disk; reopen does not rescan until you
  tap refresh.
- **Delivery per prayer** — Cast (default), beep on the phone, or adhan on
  the phone. Cast while away from home stays silent (no phone fallback).
- **Scheduled path** — Android exact alarm at T−120, then Cast at azan.
  Uses the speaker’s current volume (does not boost). Muted (0) is the only
  case that applies a fallback level so adhan is not silent.
- **Dry-run** on Waktu sholat: *Dalam 10 menit* / *Dalam 1 jam* fires the
  same alarm → foreground service → Cast path as a real prayer. No Save
  needed. After it fires, the next real prayer is re-armed.
- **EN / ID**, Ko-fi support, launcher icons and native splash from
  `assets/icons/`.

Away from home Wi‑Fi the phone speaker does **not** play adhan unless that
prayer is set to beep or phone adhan.

## Develop

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test
```

Icons / splash after changing `assets/icons/`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Install a debug APK without wiping data:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Do not use `flutter install` unless you intend a release build — it can
pick a stale `app-release.apk` and uninstall the app (data wipe). After any
install, open the app once so the next prayer alarm re-arms.

## Release signing (Play)

Release builds use an **upload keystore**, not debug keys. Play App Signing
keeps the app signing key; this repo only needs the upload key.

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Create `android/upload-keystore.jks` (once; keep it forever):

```bash
keytool -genkeypair -v -storetype JKS \
  -keystore android/upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

3. Fill `storePassword`, `keyPassword`, `keyAlias`, and `storeFile` in
   `android/key.properties`. `storeFile` is relative to `android/app/`
   (`../upload-keystore.jks`).

`key.properties`, `*.jks`, and `*.keystore` are gitignored. Back up the
JKS and both passwords offline. Losing them means you cannot update the
Play listing unless Play App Signing is already enabled with a recoverable
upload key.

```bash
flutter build appbundle --release
```

Do not install that AAB/APK over the debug build on a phone that already
has live alarms — different signatures will force an uninstall.

## Tests

```bash
flutter test
```

Focused areas: Cast session / volume, delivery orchestrator, speaker setup
states, prayer prefs and settings, Home widget shell.

## Play listing

Play Console **privacy policy URL** must be the Prayer Cast page, not the
generic studio policy at `/privacy`:

https://tursinalabs.com/privacy/prayer-cast

Store listing copy (short/full description, screenshots, feature graphic):
[docs/play-store-listing.md](./docs/play-store-listing.md).

Data safety form answers: [docs/play-data-safety.md](./docs/play-data-safety.md).

Foreground service Play answers: [docs/play-fgs.md](./docs/play-fgs.md).

Cleartext HTTP is disabled for the app process
(`usesCleartextTraffic` is not set; `network_security_config.xml` keeps
`base-config` cleartext false). The on-device media server still advertises
`http://<LAN-IP>:<port>/...` because the Cast speaker fetches that URL;
the phone does not. Aladhan, myQuran (Indonesia Kemenag), Ko-fi, the
privacy policy, and geocoding are HTTPS. Android cannot CIDR-whitelist RFC1918 in `domain-config`, so a
global or fake-IP allowlist is not used.

## License / data

Prayer prefs, home speaker id, and delivery logs stay on the device.
Adzan audio is bundled under `assets/audio/`.
See [docs/play-data-safety.md](./docs/play-data-safety.md) for what leaves
the device toward Aladhan, myQuran, geocoder, and Google Cast.
