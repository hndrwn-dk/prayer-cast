# QA enhancements: setup card, theme, legal, store frames

**Date:** 2026-10-03  
**Status:** Draft — awaiting review  
**Product:** Prayer Cast (Flutter / Android)  
**Source:** Testers Community report, section "Opportunities for Enhancement"

## Problem

QA found no crashes. They asked for four product improvements:

1. Guidance for new users (prayer times, adhan, speaker).
2. Play Store screenshots that sell features, with caption overlays, not a dump of every screen.
3. Light / Dark / System theme.
4. Terms of Service in Settings (Privacy already exists, but on an old URL).

## Goals

- First-run users can complete setup from a dismissible home checklist without a slide deck or coach marks.
- Every screen follows Light, Forest (current dark), or System. Forest look (palette, dawn/mist hairlines, 56px taps, Atkinson / Fraunces) is not deleted.
- Settings Legal opens the live privacy page and the terms URL we were given.
- Play listing gets four branded phone frames with short overlays.

## Non-goals

- Full-screen intro slides or coach-mark spotlights.
- First-launch Terms prompt or blocking legal gate.
- In-app Terms/Privacy HTML.
- A third custom palette.
- Screenshots of Settings, Qibla, tracker, theme picker, or the setup card itself.
- Publishing the terms HTML page (ops; app still links the URL).
- Uploading frames to Play Console (deliver files; human uploads).

## Decisions

| Topic | Choice |
|--------|--------|
| Walkthrough | Dismissible first-run **checklist card** on home |
| Theme | Light + Forest + System on **every** screen |
| Default theme | System |
| Legal | Update Privacy URL; add Terms row |
| Store shots | Four overlay frames, not every screen |
| Existing users | No setup card if `PrayerPrefs.configured` is already true |

## 1. First-run checklist card

Place one card on home, below the next-adhan hero and above the speaker band. Forest chrome, same family as the exact-alarm / notification banners.

### Visibility

On each home build:

1. If `setupCardDismissed` is set → hide.
2. Else if this install has never written setup-card flags, and `configured == true` → treat as an existing user: set `setupCardDismissed` and hide (no retroactive nag).
3. Else show the card.

Hide without Dismiss once required rows are done: prayer `configured`, and speaker saved **or** `setupCardNoSpeaker`. Reminders row can stay unticked; it does not keep the card visible.

**Dismiss:** sets `setupCardDismissed` and hides immediately.

Persist flags in a small on-device file next to locale (not Android SharedPreferences from Dart), same pattern as `FileLocaleStore`.

### Rows

1. **Home speaker** — opens `SpeakerSetupPage`. Done when `savedHomeSpeaker != null`. Secondary: **Use this phone** sets `setupCardNoSpeaker` and completes this row without a Cast device.
2. **Prayer times** — opens `PrayerSettingsPage`. Done when `configured == true`.
3. **No speaker: phone or beep** — visible only if `setupCardNoSpeaker` and no saved speaker. Opens Prayer settings focused on delivery mode. Done when `defaultDeliveryMode` is `adhanPhone` or `beep` (or `takbir`) after save. Hidden if a speaker is saved.
4. **Reminders** — one row. Opens Prayer settings scrolled to pre-prayer + iqamah. Done when `setupCardRemindersSeen` is set after a successful save of Prayer settings opened from this row. Leaving a reminder off is allowed.

Tapping a row does not auto-advance to the next page. The user returns to home and sees ticks.

Copy: English and Indonesian (`l10n`).

## 2. Theme (Light / Forest / System)

### What users pick (Settings, language-style rows)

| Choice | `ThemeMode` | Look |
|--------|-------------|------|
| System (default) | `ThemeMode.system` | Phone light → Light; phone dark → Forest |
| Forest | `ThemeMode.dark` | Current dark (`PrayerCastTheme.forest()`) |
| Light | `ThemeMode.light` | Existing `PrayerCastTheme.light()` |

Persist `system` / `forest` / `light` in a file next to locale.

### How it is wired

- `MaterialApp.theme` = `PrayerCastTheme.light()`
- `MaterialApp.darkTheme` = `PrayerCastTheme.forest()`
- `MaterialApp.themeMode` from the stored choice
- Remove per-page `Theme(data: PrayerCastTheme.forest())` wrappers so the choice applies

### Colors and hairlines

Do **not** delete `PrayerCastColors`, `EditorialHairline`, or `cardHairline`.

Widgets that hardcode `PrayerCastColors.ink` (and similar) must read from `Theme.of(context).colorScheme` or a thin token helper that maps Light vs Forest. Forest values stay the current ink / canopy / dawn. Light values stay the current mist / surface tokens. Hairlines stay dawn or mist on both; they do not disappear.

Home hero (canopy, crescent) uses Forest tokens when dark, Light tokens when light. No mixed-theme screens.

## 3. Legal links

`AppLinks`:

- Privacy: `https://www.tursinalabs.com/prayercast/privacy` (replace `https://tursinalabs.com/privacy/prayer-cast`)
- Terms: `https://www.tursinalabs.com/prayercast/terms`

Settings Legal: Privacy row (updated URL), then Terms of Service row. Both use `openExternalUrl`. Tests that assert the old privacy URL must use the new one.

Also update `docs/play-store-listing.md` privacy URL in the same change so Console copy does not drift.

Terms may 404 until the page is published. The app still ships the link.

## 4. Play Store frames

Not a screenshot of every route. Four phone frames, same crop, overlay bar (Fraunces / Atkinson, dawn hairline, forest or mist panel).

| # | In-app view | Overlay EN | Overlay ID |
|---|----------------|------------|------------|
| 1 | Home hero, next adhan | Adhan at the right time, even when the phone sleeps. | Adzan di waktunya, termasuk saat HP tidur. |
| 2 | Home speaker band or setup with a saved speaker | Adhan on the speaker at home. | Adzan di speaker rumah. |
| 3 | Prayer settings delivery (phone / beep) | No speaker? Play adhan or a beep on the phone. | Tanpa speaker? Adzan atau beep di HP. |
| 4 | Prayer settings reminders | Nudge before azan, and again at iqamah. | Pengingat sebelum azan, dan lagi saat iqamah. |

Capture on the running emulator **after** the in-app work is installed, so frames match the new UI. Output PNG files under `docs/store/play-screenshots/` (do not commit huge binaries unless asked). Overlay can be a Flutter export screen or a short compose step; visual style must match brand, not Material stock banners.

## Implementation order

1. Legal URLs + Settings Terms row (smallest, unblocks listing docs).
2. First-run card.
3. Theme (largest).
4. Store frames on emulator.

## Test plan

- Settings Privacy launches the new privacy URL; Terms launches the terms URL.
- Setup card hidden when `configured` is already true.
- Card shows for a fresh prefs store; Dismiss hides it after restart.
- Speaker row completes on save; "Use this phone" shows the delivery row and hides it if a speaker is later saved.
- Reminders row completes after save from that entry, even if pre-prayer minutes stay 0.
- ThemeMode system/light/dark: a wrapped screen uses light ColorScheme in Light and forest ColorScheme in Forest; no remaining `Theme(data: forest())` override on those routes.
- Existing coordinator and prayer-settings tests still pass.

## Risks

- Light mode misses a hardcoded ink color → unreadable. Mitigate with a widget test that pumps key routes in Light and checks `ColorScheme.brightness`.
- Setup card annoys returning testers who already configured. Mitigate with the `configured` skip.
- Terms 404 in review. Accept; publish the page before Play review if possible.
- Store overlays in two languages: deliver EN and ID as separate files (`*-en.png`, `*-id.png`) so Console listings can differ.
