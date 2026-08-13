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
| `makkah` | `makkah.wav` | Short test tone (optional) |

Defaults: Subuh → `fajr_adhan`; other prayers → `standard_adhan`.
