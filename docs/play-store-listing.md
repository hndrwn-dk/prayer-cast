# Play Console listing — Prayer Cast

Copy-paste ready for `com.tursinalabs.prayer_cast`.
Answers match app behavior as of 15 August 2026.

Privacy policy URL (Play Console **App content → Privacy policy**):

https://tursinalabs.com/privacy/prayer-cast

Do **not** use the generic studio page at `/privacy`.

Related Play forms:

- Data safety: [play-data-safety.md](play-data-safety.md)
- Foreground services: [play-fgs.md](play-fgs.md)

## Category

**Lifestyle**

Prayer times and home adhan are a daily household ritual, not a
developer utility. Lifestyle matches other prayer / home-routine apps
better than Tools.

## Content rating

Religious / general audience.

Do **not** enroll in Designed for Families. The app is for adults
setting household prayer audio, not a children’s app.

## Short description (80 characters max)

### English (67)

```
Offline prayer times. Cast adhan at home. No account. Optional GPS.
```

### Indonesian (69)

```
Jadwal sholat offline. Cast adzan di rumah. Tanpa akun. GPS opsional.
```

## Full description

### English

```
Prayer Cast is an offline-first prayer times app. When you are actually
home, it can cast the adhan once to your Google Cast / Nest speaker.

No account. No ads. No in-app purchases.

Prayer times
• Fetch a schedule from Aladhan by city, or use optional GPS to fill
  city and country only.
• In Indonesia, Kemenag jadwal is fetched from myQuran using a city
  id only (not coordinates).
• GPS is never used to decide whether you are home. Home uses an
  on-device Wi-Fi / LAN fingerprint.
• Singapore MUIS (method 11) and Hanafi / Shafi’i Asr.
• Per-prayer delivery: Cast (default), beep on the phone, or adhan on
  the phone.

Home speaker
• Scan the local network and pick a Cast speaker (or a group you
  already made in Google Home).
• Adhan plays on the speaker only when you are home. Away stays silent
  unless that prayer is set to beep or phone adhan.

Privacy
• Prayer prefs, speaker id, and delivery logs stay on the phone.
• Tursina Labs does not run a backend for this app.
• Optional location is sent only to Aladhan, myQuran (Indonesia
  Kemenag city id), and the system geocoder.
• Privacy policy: https://tursinalabs.com/privacy/prayer-cast

Support
• Ko-fi is a donation in the system browser. It does not unlock
  features and is not an in-app purchase.
```

### Indonesian

```
Prayer Cast adalah aplikasi waktu sholat yang mengutamakan offline.
Saat Anda benar-benar di rumah, adzan bisa diputar sekali ke speaker
Google Cast / Nest.

Tanpa akun. Tanpa iklan. Tanpa pembelian dalam aplikasi.

Waktu sholat
• Ambil jadwal dari Aladhan dengan mengetik kota, atau pakai GPS
  opsional hanya untuk mengisi kota dan negara.
• Di Indonesia, jadwal Kemenag diambil dari myQuran memakai id kota
  saja (bukan koordinat).
• GPS tidak dipakai untuk menentukan apakah Anda di rumah. Deteksi
  rumah memakai sidik LAN / Wi-Fi di ponsel.
• Metode MUIS Singapura (11) dan Asar Hanafi / Syafi’i.
• Penyampaian per waktu: Cast (baku), beep di HP, atau adzan di HP.

Speaker rumah
• Pindai jaringan lokal dan pilih speaker Cast (atau grup yang sudah
  dibuat di Google Home).
• Adzan di speaker hanya saat Anda di rumah. Saat tidak di rumah,
  HP tetap sunyi kecuali waktu itu disetel beep atau adzan di HP.

Privasi
• Preferensi sholat, id speaker, dan log pengiriman tetap di ponsel.
• Tursina Labs tidak menjalankan server untuk aplikasi ini.
• Lokasi opsional hanya dikirim ke Aladhan, myQuran (id kota Kemenag
  Indonesia), dan geocoder sistem.
• Kebijakan privasi: https://tursinalabs.com/privacy/prayer-cast

Dukungan
• Ko-fi adalah donasi di peramban sistem. Tidak membuka fitur dan
  bukan pembelian dalam aplikasi.
```

## Permission declarations (App content)

### Location (approximate / coarse)

```
Optional. Used only when the user taps Use current location on Prayer
times, to fill city and country and fetch the Aladhan schedule.
Not used to decide if the user is home (LAN fingerprint). Not used
for speaker scan. Not requested on launch or in the background.
Users can type city and country instead.
```

### Nearby Wi-Fi devices

```
Used only to discover Google Cast / Nest speakers on the same Wi-Fi
when the user opens Home speaker and scans. Declared neverForLocation:
Wi-Fi is not used as a location source. Not requested on launch.
On Android 12 and below, scan uses Wi-Fi state and multicast only;
Scan does not request location.
```

Do **not** justify speaker scan with Fine location. Fine location is
removed from the manifest (`tools:node="remove"`).

## Feature graphic (1024 x 500)

File (in this repo):

`docs/store/play_feature_graphic_1024x500.png`

On-brand: ink / mist / dawn gold, Fraunces-like wordmark “Prayer Cast”,
no emoji. Tagline: “Adhan at home, once.” Subline: “Optional city. No
account.”

There is also a older Play graphic at
`assets/icons/play_feature_graphic_1024x500.png`. Prefer the
`docs/store/` file for Console upload so copy matches this listing
(optional city GPS, not “No GPS”).

## Phone screenshots (shot list)

These shots are **not** stored in this repo. Capture on a phone
(or emulator) after sideloading a matching-signature build. Do not
`flutter install` over a live debug APK.

Capture in **English** and **Indonesian** (switch language on Home).

1. **Home** — next adhan, home / not-home chip, speaker card, Prayer
   times row, privacy line. Shows the product in one screen.
2. **Speaker setup** — scanning or a found Cast speaker list, plus the
   group-delay hint. Shows local-network scan, not GPS.
3. **Prayer times** — city / “Use current location”, method, today’s
   schedule with Cast / beep / phone. If you tap current location on a
   fresh grant, also capture the in-app location disclosure (GPS
   optional, not used for home) **before** the system permission sheet.
4. **Dry-run / test** — Prayer times “Test scheduled adhan” card
   (In 10 minutes / In 1 hour), or a prayer row after the speaker
   test. Shows the reviewer how to exercise the alarm path.

Optional fifth: location disclosure dialog alone, if shot 3 does not
show it clearly.

## Reviewer notes

- Home copy “no GPS” means home detection is not GPS. Optional GPS
  exists only on Prayer times to fill city.
- Ko-fi is a browser donation, not IAP. Do not declare financial info.
- AdzanForegroundService is specialUse, not mediaPlayback. See
  [play-fgs.md](play-fgs.md).
