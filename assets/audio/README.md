# Adzan audio assets

Expected layout:

```
assets/audio/{voiceId}.mp3
assets/audio/{voiceId}.wav
```

## Subuh (`fajr`)

| voiceId | File |
|---------|------|
| `fajr_adhan` | `fajr_adhan.mp3` (default) |
| `fajr_mansur_al_zahrane` | `fajr_mansur_al_zahrane.mp3` |
| `fajr_mishary_rashid_alafasy` | `fajr_mishary_rashid_alafasy.mp3` |
| `beep` | `beep.wav` |
| `long_beep` | `long_beep.wav` |

## Dzuhur / Asar / Maghrib / Isya

| voiceId | File |
|---------|------|
| `standard_adhan` | `standard_adhan.mp3` (default) |
| `ahmed_al_haddad` | `ahmed_al_haddad.mp3` |
| `mishary_rashid_alafasy` | `mishary_rashid_alafasy.mp3` |
| `muhammad_ramadan_saad` | `muhammad_ramadan_saad.mp3` |
| `nurdin_hamza_al_maghriby` | `nurdin_hamza_al_maghriby.mp3` |
| `ali_ibn_ahmad_mala` | `ali_ibn_ahmad_mala.mp3` |
| `beep` | `beep.wav` |
| `long_beep` | `long_beep.wav` |

Defaults: Subuh → `fajr_adhan`; other prayers → `standard_adhan`.
The prayer settings voice picker only lists the table that matches the prayer.
