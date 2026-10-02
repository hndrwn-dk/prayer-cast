# Play Store screenshot copy

Four phone frames. Mount `PlayStoreCaptionBar` at the **top** of the capture stack while shooting so the navigation bar stays clear. Remove it before a release build. Do not commit the PNGs under `docs/store/play-screenshots/`.

Overlay copy is verbatim. Indonesian shot 4 uses "dan".

| File stem | Screen | EN | ID |
|-----------|--------|----|----|
| `01-next-adhan` | Home with a configured next prayer. Dismiss the setup card first. | Adhan at the right time, even when the phone sleeps. | Adzan di waktunya, termasuk saat HP tidur. |
| `02-home-speaker` | Speaker band with a speaker name. | Adhan on the speaker at home. | Adzan di speaker rumah. |
| `03-phone-adhan` | Prayer settings, delivery section. | No speaker? Play adhan or a beep on the phone. | Tanpa speaker? Adzan atau beep di HP. |
| `04-reminders` | Prayer settings, reminders section. | Nudge before azan, and again at iqamah. | Pengingat sebelum azan, dan lagi saat iqamah. |

## Caption bar

`PlayStoreCaptionBar(text: ...)` is a full-width panel:

- Forest fill: `PrayerCastColors.canopyDeep`
- Light fill: `PrayerCastTokens.surface`
- Dawn `EditorialHairline`
- Caption: Fraunces 22. Panel body metric: Atkinson Hyperlegible 16
- Padding: 24

Place it as the top child of a `Stack` over the screen under capture. It pins itself to the top and does not cover the navigation bar.

English pass first. Switch language to Indonesian in Settings, then repeat the same four screens.

Status bar: use a clean emulator clock if the emulator image allows it.

Device: `emulator-5554` only if it is already running. Do not start a new emulator.

## Commands

```bash
mkdir -p docs/store/play-screenshots

adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/01-next-adhan-en.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/02-home-speaker-en.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/03-phone-adhan-en.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/04-reminders-en.png

adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/01-next-adhan-id.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/02-home-speaker-id.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/03-phone-adhan-id.png
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/04-reminders-id.png
```

Shot 1: home, next prayer configured, setup card hidden (Dismiss).

Shot 2: speaker band showing a name.

Shot 3: Prayer settings delivery section.

Shot 4: Prayer settings reminders section.
