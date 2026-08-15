# Play release notes

Paste into Play Console "Release notes". Keep the language tags. Play allows
500 characters per language.

## 1.0.0 (versionCode 1)

```
<en-US>
First release of Prayer Cast.

- Offline-first prayer times by city, or optional GPS
- Kemenag schedule for cities in Indonesia; Aladhan methods elsewhere (MUIS, Muslim World League, ISNA and more)
- Cast the adhan to a Google Cast or Nest speaker, only when you are actually home
- Only one phone in the household plays, so the adhan is not doubled
- Pick Cast, phone adhan, or a beep for each prayer
- Test a scheduled adhan before you rely on it
- English and Bahasa Indonesia
- No account. Your data stays on your phone.
</en-US>
<id-ID>
Rilis pertama Prayer Cast.

- Waktu sholat offline-first berdasarkan kota, atau GPS opsional
- Jadwal Kemenag untuk kota di Indonesia; metode Aladhan di luar Indonesia (MUIS, Muslim World League, ISNA, dan lain-lain)
- Adzan dikirim ke speaker Google Cast atau Nest, hanya saat Anda benar-benar di rumah
- Hanya satu ponsel di rumah yang memutar, sehingga adzan tidak dobel
- Pilih Cast, adzan di ponsel, atau beep untuk setiap sholat
- Uji adzan terjadwal sebelum Anda mengandalkannya
- Bahasa Indonesia dan Inggris
- Tanpa akun. Data Anda tetap di ponsel.
</id-ID>
```

## Upload checklist

Build:

```bash
flutter build appbundle --release
```

Artifact: `build/app/outputs/bundle/release/app-release.aab`

- Signed with the upload key from `android/key.properties`, not debug keys.
  Verify: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
- Play App Signing holds the app signing key; this AAB only carries the
  upload signature.
- Privacy policy URL must be the Prayer Cast page, not the studio page:
  https://tursinalabs.com/privacy/prayer-cast
- Data safety answers: `play-data-safety.md`
- Foreground service declaration (specialUse): `play-fgs.md`
- Store listing copy and graphics: `play-store-listing.md`
- Permission justifications: Location (optional, prayer city only) and
  Nearby Wi-Fi devices (Cast speaker scan, neverForLocation).

Do not install this AAB or its APKs over a debug build on a phone that has
live alarms. The signatures differ, so Android forces an uninstall and the
schedule is lost.
