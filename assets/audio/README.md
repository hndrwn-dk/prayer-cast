# Adzan audio assets

Expected layout:

```
assets/audio/{voiceId}.mp3
```

Example: `assets/audio/makkah.mp3`

**OPEN TASK:** Real adzan recordings are not bundled yet. Until they land,
`AssetAdzanAudioLoader` falls back to a silent MPEG test tone so the delivery
pipeline can be wired. Do not ship that fallback as production audio.
