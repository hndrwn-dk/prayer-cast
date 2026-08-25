# Prayer Cast

Tursina Labs — prayer times on your phone, and adhan on a home speaker when
you are actually home. No account.

## What it does

- **Prayer times** for your city. Location is optional; you can type city
  and country instead.
- **Home speaker** — scan the network and pick a Google Cast / Nest
  speaker, including groups you already made in Google Home.
- **Adhan at prayer time** on that speaker when you are home. Each prayer
  can instead beep or play adhan on the phone.
- **Notifications** for the upcoming prayer, in English or Indonesian.

Away from home, the phone stays silent unless that prayer is set to beep
or phone adhan.

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
pick a stale `app-release.apk` and uninstall the app (data wipe). After
any install, open the app once so the next prayer is scheduled.

## Tests

```bash
flutter test
```

## License

Copyright Tursina Labs. Source in this repository is for the Prayer Cast
app and is not offered under an open-source license.
