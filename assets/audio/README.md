# Adzan audio assets

Expected layout:

```
assets/audio/{voiceId}.mp3
assets/audio/{voiceId}.wav
```

Bundled voices:

| voiceId | File | Used for |
|---------|------|----------|
| `fajr_adhan` | `fajr_adhan.mp3` | Subuh (default) |
| `standard_adhan` | `standard_adhan.mp3` | Dzuhur, Asar, Maghrib, Isya (default) |
| `ahmed_al_haddad` | `ahmed_al_haddad.mp3` | Standard |
| `mansur_al_zahrane` | `mansur_al_zahrane.mp3` | Standard |
| `mishary_rashid_alafasy_fajr` | `mishary_rashid_alafasy_fajr.mp3` | Fajr |
| `mishary_rashid_alafasy` | `mishary_rashid_alafasy.mp3` | Standard |
| `muhammad_ramadan_saad` | `muhammad_ramadan_saad.mp3` | Standard |
| `nurdin_hamza_al_maghriby` | `nurdin_hamza_al_maghriby.mp3` | Standard |
| `ali_ibn_ahmad_mala` | `ali_ibn_ahmad_mala.mp3` | Standard |
| `makkah` | `makkah.wav` | Short test tone (optional) |

Defaults: Subuh → `fajr_adhan`; other prayers → `standard_adhan`.
Every id in this table appears in the Prayer settings voice dropdown.
