# Prayer Cast

Tursina Labs — offline-first prayer times. When you are actually home, the
app casts the adzan to your Google Cast / Nest speaker, once across family
phones.

See [ADZAN_HOME_DELIVERY_SPEC.md](./ADZAN_HOME_DELIVERY_SPEC.md) for the
`home_delivery` layer (presence → coordination → cast).

## What it does

- **Prayer times** from Aladhan (city or GPS). Singapore MUIS is method 11.
  Hanafi vs Shafi'i changes **Asr only** (Hanafi is later).
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

## Tests

```bash
flutter test
```

Focused areas: Cast session / volume, delivery orchestrator, speaker setup
states, prayer prefs and settings, Home widget shell.

## License / data

Prayer prefs, home speaker id, and delivery logs stay on the device.
Adzan audio is bundled under `assets/audio/`.
