# Play Store screenshot copy

Four phone frames. Mount `PlayStoreCaptionBar` at the **top** of the capture stack while shooting so the navigation bar stays clear. Remove it before a release build. Do not commit the PNGs under `docs/store/play-screenshots/`.

Overlay copy is verbatim. Indonesian shot 4 uses "dan".

| File stem | Screen | EN | ID |
|-----------|--------|----|----|
| `01-next-adhan` | Home with a configured next prayer (onboarding completed). | Adhan at the right time, even when the phone sleeps. | Adzan di waktunya, termasuk saat HP tidur. |
| `02-home-speaker` | Same home frame; speaker band shows a saved name (e.g. Living Room). | Adhan on the speaker at home. | Adzan di speaker rumah. |
| `03-phone-adhan` | Prayer settings, delivery section (phone / beep modes). | No speaker? Play adhan or a beep on the phone. | Tanpa speaker? Adzan atau beep di HP. |
| `04-reminders` | Prayer settings, reminders section (pre-prayer + iqamah). | Nudge before azan, and again at iqamah. | Pengingat sebelum azan, dan lagi saat iqamah. |

## Caption bar

`PlayStoreCaptionBar(text: ...)` is a full-width panel:

- Forest fill: `PrayerCastColors.canopyDeep`
- Light fill: `PrayerCastTokens.surface`
- Dawn `EditorialHairline`
- Caption: Fraunces 22. Panel body metric: Atkinson Hyperlegible 16
- Padding: 24

Place it as the top child of a `Stack` over the screen under capture. It pins itself to the top and does not cover the navigation bar.

Capture build uses `--dart-define=PLAY_STORE_CAPTURE=true`. That mounts
`PlayStoreCaptureLayer`, which reads `play_store_shot.txt` (`01-en` … `04-id`)
from app documents and opens the matching route.

English pass first, then Indonesian (`app_locale.txt` = `en` / `id`).

Status bar: use a clean emulator clock if the emulator image allows it.

Device: `emulator-5554` only if it is already running. Do not start a new emulator.

## Commands

```bash
mkdir -p docs/store/play-screenshots

# After seeding prefs / speaker / locale into app_flutter and installing
# the capture debug APK:
adb -s emulator-5554 shell "run-as com.tursinalabs.prayer_cast sh -c 'printf %s 01-en > app_flutter/play_store_shot.txt'"
adb -s emulator-5554 shell am force-stop com.tursinalabs.prayer_cast
adb -s emulator-5554 shell am start -W -n com.tursinalabs.prayer_cast/.MainActivity
# wait for home / route, then:
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/01-next-adhan-en.png
```

Output stems on disk may also be `01-en.png` … `04-id.png` (same eight frames).
Do not commit the PNGs.
