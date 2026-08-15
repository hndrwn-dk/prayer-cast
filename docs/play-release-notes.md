# Play release upload

Release notes and AABs are kept out of git, in `bundles_release/`
(gitignored). See `bundles_release/README.md` for the layout and the
per-release checklist.

- **AAB:** `bundles_release/<version>/app-release-<version>.aab`
- **Release notes:** `bundles_release/play-console/PLAY_STORE_<version>.txt`

Keep release notes short: a few lines per language, `<id>` then `<en-US>`,
matching the sibling Tursina Labs apps.

## Build

```bash
flutter build appbundle --release
```

Artifact: `build/app/outputs/bundle/release/app-release.aab`

Verify it carries the upload key and not debug keys:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## Play Console checklist

- Privacy policy URL must be the Prayer Cast page, not the studio page:
  https://tursinalabs.com/privacy/prayer-cast
- Data safety answers: `play-data-safety.md`
- Foreground service declaration (specialUse): `play-fgs.md`
- Store listing copy and graphics: `play-store-listing.md`
- Permission justifications: Location (optional, prayer city only) and
  Nearby Wi-Fi devices (Cast speaker scan, neverForLocation).

Do not install a release AAB or APK over a debug build on a phone that has
live alarms. The signatures differ, so Android forces an uninstall and the
schedule is lost.
